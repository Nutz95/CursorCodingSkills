---
name: solid-python
description: >-
  SOLID Python guardrails: max 400 lines/file, max 30 methods/class, no object/Any,
  concrete TypedDict/dataclass typing, exactly one type per file, no nested classes,
  no tuple[T, ...] collections or tuple returns. Use when writing or reviewing
  Python, APIs, DTOs, Flask/FastAPI services, or when the user mentions typing,
  modularity, or file-size limits.
---

# SOLID Python

## Hard limits

- Max **400 lines** per `.py` file
- Max **30 methods** per class
- **Exactly one** top-level type per file: `class` / `TypedDict` / `Enum` / `Protocol` / exception
- **No nested classes** (extract to a sibling module)
- **No** `tuple[T, ...]` collections — use `list[T]`
- **No** heterogeneous tuple returns / multi-value unpacking APIs — use a `dataclass`

## Typing (non-negotiable)

Never use `object`, `typing.Any`, bare `dict`, bare `list`, or bare `tuple`.

Prefer:

- `TypedDict`, `dataclass`, `Enum`, `X | None`
- `list[Concrete]`, `dict[str, Concrete]`
- Annotated public function parameters and return types

Forbidden:

```python
def handle(self, payload: object) -> Any: ...
items: list = []
channels: tuple[ChannelReading, ...]
def parse(self, payload: str) -> tuple[tuple[PowerSample, ...], float | None]: ...
def _split_uid(self, raw: str) -> tuple[str, ChannelLabel]: ...
```

Allowed:

```python
def to_payload(self, snapshot: SystemSnapshot) -> SnapshotPayload: ...
channels: list[ChannelPayload] = []
def parse(self, payload: str) -> PowerGraphResult: ...
def _split_uid(self, raw: str) -> InverterUidChannel: ...
```

### Collections: list, not variadic tuple

Prefer `list[T]` for domain collections (channels, samples, ids).

Frozen dataclasses that hold `list[T]` must copy in `__post_init__`
(`object.__setattr__(self, "items", list(self.items))`) so callers cannot mutate
shared state through a published model.

### Multi-field shapes: dataclass, not stacked tuples

If a function returns more than one value, or a pair/triple of different types,
define a dedicated frozen dataclass (one file) instead of `tuple[A, B]`.

### Sole exception

Flask/Werkzeug status pairs only: `Response | tuple[Response, int]`.

## SOLID habits

- Split before growing a god-module
- Keep parsers / clients / services / presenters in separate files
- Catch concrete exceptions and chain with `from error`
- No inline imports unless a documented circular-dependency exception

## Checklist

- [ ] File stays under 400 lines
- [ ] Exactly one type definition in the file
- [ ] No nested class
- [ ] No `object` / `Any` / bare collections
- [ ] No variadic tuples and no domain multi-value tuple returns
- [ ] New JSON shapes have a TypedDict
- [ ] One responsibility per module
