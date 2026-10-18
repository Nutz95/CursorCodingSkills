---
name: solid-python
description: >-
  SOLID Python guardrails: max 400 lines/file, max 30 methods/class, no object/Any,
  concrete TypedDict/dataclass typing, exactly one type per file, no nested classes,
  no tuple[T, ...] collections or tuple returns, strict DI at composition roots
  (Protocol / ABC boundaries, fakes for tests — no test ifdefs in production).
  Use when writing or reviewing Python, APIs, DTOs, Flask/FastAPI services, or when
  the user mentions typing, modularity, DI, or file-size limits.
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
- Annotated public function parameters and return type

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

## Architecture (SOLID + DI)

Keep production modules testable without `#ifdef`-style branching or `if TYPE_CHECKING`
hacks that change runtime behavior for tests.

- Prefer **`Protocol` / ABC** at domain boundaries (`ITelemetryStore`, `Clock`, `HttpClient`, …)
- Application / domain code depends on abstractions only
- Construct **concrete adapters** (filesystem, HTTP, serial, DB, GPIO) only in a
  composition root: `main.py`, `app_factory.py`, CLI entry, or a dedicated `wiring/` module
- Unit tests inject fakes / in-memory doubles — do **not** sprinkle `if os.environ.get("TEST")`
  or production `if TYPE_CHECKING` runtime forks to stub I/O
- One responsibility per module: parsers, clients, services, presenters stay separate

Smell → fix:

| Smell | Fix |
|-------|-----|
| Service imports `requests` and is hard to unit-test | Inject `HttpClient` Protocol; fake in tests |
| `if TESTING: ...` inside domain logic | Composition root swaps adapters |
| God class knows HTTP + parse + persist | Split; wire in composition root |

## Secrets

- Never hardcode API tokens, passwords, or connection strings in committed source
- Load from env / secret store at the composition root; pass typed config into adapters

## SOLID habits

- Split before growing a god-module
- Catch concrete exceptions and chain with `from error`
- No inline imports unless a documented circular-dependency exception

## Checklist

- [ ] File stays under 400 lines
- [ ] Exactly one type definition in the file
- [ ] No nested class
- [ ] No `object` / `Any` / bare collections
- [ ] No variadic tuples and no domain multi-value tuple returns
- [ ] New JSON shapes have a TypedDict
- [ ] Domain depends on Protocol/ABC; concretes only at composition root
- [ ] Tests use fakes — no production test-only branching
- [ ] One responsibility per module
