---
name: esp-rgb565-color
description: >-
  Convert RGB888 to RGB565 for TFT_eSPI / ST7735 / ST7789 on ESP32: packing
  formula, sprite present endian traps, BGR MADCTL, mid-tone pink/violet bugs.
  Use when picking UI palette colors, writing sprites, or bursting pixels over SPI.
---

# ESP32 RGB565 colors (TFT_eSPI)

## Why this exists

Hand-picked `0xD69A` / `TFT_LIGHTGREY` literals often look **wrong** on ESP32-S3
ST7735 panels (blue/violet grays, pink “blacks”, violet “yellows”). Causes:

1. **RGB565 packing** mistakes (wrong bit widths)
2. **Wrong present endian** — sprite buffer vs `pushPixels` / `writeBytes` / `writePixels`
3. **MADCTL BGR** — panel color order vs what you think you wrote

Prefer a tiny helper that only packs RGB888 → RGB565; keep SPI endian in the
present path, not in the palette.

## Pack RGB888 → RGB565

```cpp
// RRRRR GGGGGG BBBBB  (panel MADCTL BGR bit still applies in hardware)
constexpr uint16_t fromRgb(uint8_t r, uint8_t g, uint8_t b) {
  return static_cast<uint16_t>(((r & 0xF8) << 8) | ((g & 0xFC) << 3) | (b >> 3));
}
```

Example helper (put it in your board HAL, any namespace/name):

```cpp
#pragma once
#include <cstdint>

struct Rgb565Color {
  static constexpr uint16_t fromRgb(uint8_t red, uint8_t green, uint8_t blue) {
    return static_cast<uint16_t>(((red & 0xF8u) << 8) | ((green & 0xFCu) << 3) |
                                 (blue >> 3));
  }
};
```

Example palette (black UI, readable secondary text, green accents):

```cpp
constexpr uint16_t kBg = Rgb565Color::fromRgb(0, 0, 0);
constexpr uint16_t kCard = Rgb565Color::fromRgb(28, 28, 28);       // dark header
constexpr uint16_t kBannerText = Rgb565Color::fromRgb(255, 255, 255);
constexpr uint16_t kAccent = Rgb565Color::fromRgb(0, 220, 120);
constexpr uint16_t kMuted = Rgb565Color::fromRgb(148, 168, 188);   // cool slate secondary
constexpr uint16_t kText = Rgb565Color::fromRgb(255, 255, 255);
constexpr uint16_t kWarn = Rgb565Color::fromRgb(255, 220, 0);
```

**Banner rule:** title text on the header bar must be **white** (or near-white), never a
saturated accent on a mid gray — contrast fails on small panels.

**Muted rule:** muted is **not** “almost white”. Use a cool slate / blue-gray so secondary
lines stay readable on black but clearly subordinate to `kText`. Near-white muted defeats
the hierarchy; pure mid-gray is fine once the present endian path is correct.

## Present path (sprite → panel) — endian trap

TFT_eSPI `TFT_eSprite::pushSprite` does:

1. `setSwapBytes(false)`
2. `pushPixels(buffer, pixelCount)` — copies the sprite’s native `uint16_t`s into the
   SPI FIFO **without** an extra CPU byte-swap

Match that. Do **not** invent a second endian transform.

```cpp
tft.startWrite();
tft.setAddrWindow(0, 0, width, height);
const bool oldSwap = tft.getSwapBytes();
tft.setSwapBytes(false);
tft.pushPixels(spritePixels, width * height);  // native RGB565 from the sprite
tft.setSwapBytes(oldSwap);
tft.endWrite();
```

| Approach | Result on mid-tones |
|----------|---------------------|
| `setSwapBytes(false)` + `pushPixels` (like `pushSprite`) | Correct |
| `SPI.writeBytes` of **native** pixels (same byte order as RAM) | Usually OK |
| Byte-swap each pixel then `writeBytes` | Gray→pink, yellow→violet |
| `SPI.writePixels` (`MSB_PIX_SET`) on sprite RAM | Same pink/violet trap |

Black (`0x0000`) and white (`0xFFFF`) look fine even when endian is wrong — that is why
a broken present path often “almost works”.

## Checklist: wrong colors

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Gray → pink, yellow → violet | Extra byte-swap on present | Use `pushPixels` / no swap |
| Green → orange (only accents) | Bad palette / contrast, not endian | White banner; `fromRgb` |
| Black/white OK, mid-tones bad | Endian only | Fix present path |
| Whole UI pink/teal | `TFT_RGB_ORDER` / inversion | Match vendor `TFT_BGR` + `TFT_INVERSION_ON` |

## Related

- Pocket ST7735 bring-up: `esp-pocket-dongle-s3-096-display`
- SOLID C++ naming: `solid-cpp-esp32` (no cryptic `spr` / `mgr` abbreviations)
