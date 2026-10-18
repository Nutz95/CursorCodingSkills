---
name: solid-python
description: >-
  SOLID Python guardrails: max 400 lines/file, max 30 methods/class, no object/Any,
  concrete TypedDict/dataclass typing, one class per file. Use when writing or
  reviewing Python, APIs, DTOs, Flask/FastAPI services, or when the user mentions
  typing, modularity, or file-size limits.
---

# SOLID Python

## Hard limits

- Max **400 lines** per `.py` file
- Max **30 methods** per class
- **One** class / TypedDict / Enum per file when practical

## Typing (non-negotiable)

Never use `object`, `typing.Any`, bare `dict`, bare `list`, or bare `tuple`.

Prefer:

- `TypedDict`, `dataclass`, `NamedTuple`, `Enum`, `X | None`
- `list[Concrete]`, `dict[str, Concrete]`, `tuple[Concrete, ...]`
- Annotated public function parameters and return types

Forbidden:

```python
def handle(self, payload: object) -> Any: ...
items: list = []
```

Allowed:

```python
def to_payload(self, snapshot: SystemSnapshot) -> SnapshotPayload: ...
channels: list[ChannelPayload] = []
```

## SOLID habits

- Split before growing a god-module
- Keep parsers / clients / services / presenters in separate files
- Catch concrete exceptions and chain with `from error`
- No inline imports unless a documented circular-dependency exception

## Checklist

- [ ] File stays under 400 lines
- [ ] No `object` / `Any` / bare collections
- [ ] New JSON shapes have a TypedDict
- [ ] One responsibility per module
