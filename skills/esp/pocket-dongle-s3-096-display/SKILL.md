---
name: esp-pocket-dongle-s3-096-display
description: >-
  Drive the Pocket-Dongle-S3-0.96 ST7735 80x160 panel with TFT_eSPI on ESP32-S3:
  correct GPIO map, PlatformIO flags, init/rotation, DRAM/PSRAM double-buffer,
  APP_CPU UI task (away from BLE/Wi-Fi), JPEG pushImage, LVGL flush, backlight
  hard-wire, SPI port trap. Use when bringing up or debugging this dongle
  display (not LilyGO T-Dongle-S3 pins).
---

# Pocket-Dongle-S3-0.96 — ST7735 display HAL

**Role of this skill:** board bring-up and drawing for the **Pocket-Dongle-S3-0.96**
panel only (pins, TFT_eSPI flags, double-buffer, APP_CPU UI). It is **not** a product
UI skill and it is **not** for the LilyGO T-Dongle-S3 (different GPIO map).

## Board identity (do not confuse)

| Board | Role | TFT MOSI/SCLK/CS/DC/RST | Backlight |
|-------|------|-------------------------|-----------|
| **Pocket-Dongle-S3-0.96** (this skill) | Compact ESP32-S3 USB dongle + 80×160 ST7735 | **11 / 10 / 12 / 13 / 14** | **Hard-wired** (LEDK → GND via ~10 Ω) |
| LilyGO T-Dongle-S3 (Setup209) | Different dongle; do not use this pin map | 3 / 5 / 4 / 2 / 1 | GPIO **38** active LOW |

Wrong pin map → Serial/`fillScreen` “works”, backlight lit, **panel stays blank**.

Schematic FPC (0.96 LCD SPI): DIN→MOSI, CLK→SCLK, DC, RST, CS→CE1; LEDK cathode to GND through resistor (always on).

## Suggested HAL layout (adapt names to your repo)

Keep board constants and UI plumbing behind small headers you own — example shape:

```
boards/<dongle>/Pins.h              # MOSI/SCLK/CS/DC/RST, size 160x80
boards/<dongle>/TftEsp32S3SpiFix.h  # REG_SPI_BASE fix (see below)
boards/<dongle>/Rgb565Color.h       # fromRgb only — see sibling skill esp-rgb565-color
boards/<dongle>/DoubleBuffer.*      # DRAM-preferred sprite pair + present()
boards/common/IUiFrameSource.h
boards/common/AppCoreDisplayUiTask.*  # APP_CPU UI pump
```

Use `#ifdef` / build flags to select Pocket vs LilyGO pin maps; do not hardcode a
product tree path from another repo.

Palette: always `fromRgb(r,g,b)` — do not hand-pick `0xD69A` / `TFT_LIGHTGREY`
literals for UI (endian + BGR MADCTL make mid-tones look pink/violet). Details in the
sibling skill `esp-rgb565-color` (see Related).

## PlatformIO — match vendor demos

Prefer the **vendor** `TFT_eSPI` tree + its `User_Setup.h` for bring-up (no `USER_SETUP_LOADED`, no command-line `-DTFT_CS=…` — those fight the ESP8266 then ESP32 redefs inside `User_Setup.h`).

```ini
lib_extra_dirs =
  <path>/Pocket-Dongle-S3-0.96-demo/Arduino/lib
build_flags =
  -include boards/<dongle>/TftEsp32S3SpiFix.h
  ; do NOT set USER_SETUP_LOADED / -DTFT_MOSI=... for smoke
```

Production (Bodmer via `USER_SETUP_LOADED`) still needs:

```ini
build_flags =
  -DUSER_SETUP_LOADED=1
  -DST7735_DRIVER=1
  -DST7735_GREENTAB160x80=1
  -DTFT_RGB_ORDER=TFT_BGR
  -DTFT_INVERSION_ON=1
  -DTFT_WIDTH=80
  -DTFT_HEIGHT=160
  -DTFT_MOSI=11
  -DTFT_SCLK=10
  -DTFT_CS=12
  -DTFT_DC=13
  -DTFT_RST=14
  -DSPI_FREQUENCY=80000000
  -DTOUCH_CS=-1
  -include boards/<dongle>/TftEsp32S3SpiFix.h
  ; NO USE_FSPI_PORT — vendor uses default SPI + SPI_PORT=FSPI(1)
```

Also:

- Prefer **`platform = espressif32 @ 6.5.0`** (Arduino **2.0.14**). Newer cores often blank the panel with TFT_eSPI.
- **Do not** use `-DUSE_FSPI_PORT` for this board: demos use default `SPI` + `SPI_PORT=FSPI(1)`. Force `REG_SPI_BASE` via a small include (IDF’s macro returns 0 for `i<2`).
- USB-Serial/JTAG: `before_reset=usb_reset`, `after_reset=watchdog_reset` (esptool ≥ 4.9).

### REG_SPI_BASE fix (minimal)

```cpp
// TftEsp32S3SpiFix.h — include before TFT_eSPI pulls Processors headers
#pragma once
#if defined(CONFIG_IDF_TARGET_ESP32S3)
#undef REG_SPI_BASE
#define REG_SPI_BASE(i) (((i) == 2) ? (DR_REG_SPI2_BASE) : (DR_REG_SPI3_BASE))
#endif
```

(Adjust if your IDF headers use different symbol names; goal: non-zero SPI base for FSPI.)

## Minimal bring-up (vendor ImageDemo style)

```cpp
#include <TFT_eSPI.h>

TFT_eSPI tft = TFT_eSPI(80, 160);

void setup() {
  Serial.begin(115200);
  tft.begin();           // demos call begin(), not only init()
  tft.setRotation(1);    // landscape 160x80
  tft.fillScreen(TFT_RED);
  delay(500);
  tft.fillScreen(TFT_GREEN);
  delay(500);
  tft.fillScreen(TFT_BLUE);
}

void loop() {}
```

Do **not** call `SPI.begin(...)` yourself before `tft.begin()`.

## Drawing UI — double buffer + APP_CPU task

Two layers (use both on this dongle):

| Piece | Role |
|-------|------|
| Double-buffer helper | 16-bpp ×2 offscreen frames (**DRAM preferred**); `present()` bursts the frame |
| APP_CPU UI task | FreeRTOS task pinned to **APP_CPU (1)**; radio stays on **PRO_CPU (0)** |

Why the diagonal wipe: on ESP32-S3, naive `pushSprite` / per-pixel SPI is slow. A full
160×80 frame takes tens of ms and the panel paints corner to corner. Prefer a DRAM
sprite pair and `present()` via `setSwapBytes(false)` + `pushPixels` (same as
`pushSprite` — see `esp-rgb565-color`). DISPOFF alone does not hide the wipe on this glass.

Keep PSRAM enabled for other heaps if needed; fall back to PSRAM for sprites only if
DRAM alloc fails (~50 KB ×2 for 160×80).

```cpp
// Sketch of a frame source + APP_CPU pump (names are yours).
class MyUi : public IUiFrameSource {
 public:
  bool isDisplayAsleep() const override { return asleep_; }
  void refreshIfDirty() override {
    TFT_eSprite& canvas = frame_.drawTarget();
    canvas.fillSprite(TFT_BLACK);
    // ... draw with fromRgb palette ...
    frame_.present();  // pushPixels, no manual byte-swap
  }
  DoubleBuffer frame_;
  bool asleep_ = false;
};

MyUi ui;
AppCoreDisplayUiTask displayTask(ui);

void beginUi(TFT_eSPI& tft) {
  tft.begin();
  tft.setRotation(1);
  ui.frame_.begin(160, 80);

  AppCoreDisplayUiTaskConfig displayUiConfig;
  displayUiConfig.taskName = "displayUi";
  displayUiConfig.refreshMs = 500;
  displayUiConfig.coreId = 1;  // APP_CPU
  displayTask.start(displayUiConfig);
  // BLE / ESP-NOW: xTaskCreatePinnedToCore(..., /*PRO_CPU*/ 0, ...);
}
```

Rules of thumb:

- Init TFT + allocate sprites **before** starting the UI task
- Notify the UI task after button / telemetry changes
- On sleep: suspend the UI task; on wake: resume (hard-wired BL still glows)
- Do **not** draw/push from the BLE task (PRO_CPU)

Raw TFT_eSPI equivalent: `setAttribute(PSRAM_ENABLE,true)`, `setColorDepth(16)`,
`createSprite(160,80,2)`, `frameBuffer(1|2)`, `pushSprite(0,0)`.

## Images (JPEG → panel)

Vendor pattern: decode with `JPEGDecoder` / `jpegDraw`, push RGB565 tiles:

```cpp
static int jpegDrawCallback(JPEGDRAW* drawRequest) {
  tft.pushImage(drawRequest->x, drawRequest->y, drawRequest->iWidth, drawRequest->iHeight,
                drawRequest->pPixels);
  return 1;
}
```

SD_MMC pins on this dongle (vendor ImageDemo): SCLK=17, MOSI=18, MISO=16, CS=47.

## LVGL flush (vendor Animation demo)

```cpp
void myDisplayFlush(lv_disp_drv_t* displayDriver, const lv_area_t* area,
                    lv_color_t* colorMap) {
  const uint32_t width = area->x2 - area->x1 + 1;
  const uint32_t height = area->y2 - area->y1 + 1;
  tft.startWrite();
  tft.setAddrWindow(area->x1, area->y1, width, height);
  tft.pushColors(reinterpret_cast<uint16_t*>(&colorMap->full), width * height, true);
  tft.endWrite();
  lv_disp_flush_ready(displayDriver);
}
// hor_res=160, ver_res=80 with setRotation(1)
```

## Checklist: blank panel, backlight on

1. Confirm **Pocket** pins (11/10/12/13/14), not LilyGO 3/5/4/2/1
2. `ST7735_GREENTAB160x80` + `TFT_BGR` + `TFT_INVERSION_ON`
3. **No** `USE_FSPI_PORT` — use the SPI base fix include instead
4. Arduino core ≤ 2.0.14 for TFT_eSPI (`platform = espressif32 @ 6.5.0`)
5. No software BL GPIO — LEDK is hard-wired
6. After flash, ensure app boots (`watchdog_reset` / power cycle)

## Checklist: tear / wrong colors

1. Sprite pair in **DRAM** when possible (log mem=DRAM vs PSRAM)
2. Draw only into the offscreen canvas, then `present()` (never `tft.fillScreen` for UI)
3. Mid-tones pink/violet ⇒ present path byte-swapped — use `pushPixels` like `pushSprite`
4. UI pump on APP_CPU (core 1); radio on PRO_CPU (0)

## Related

- Sibling Cursor skill **`esp-rgb565-color`** — source:
  `CursorCodingSkills/skills/esp/rgb565-color/SKILL.md`; after `deploy.ps1` it lands as
  `.cursor/skills/esp-rgb565-color/` in the target project (RGB888→RGB565 + present endian).
- Sibling Cursor skill **`solid-cpp-esp32`** — `skills/solid-cpp-esp32/` (dual-core section).
- Vendor demos (external pack, not this repo): `Pocket-Dongle-S3-0.96-demo/Arduino`
  (`User_Setup.h`, `ImageDemo`, `GIF/Animation`).
