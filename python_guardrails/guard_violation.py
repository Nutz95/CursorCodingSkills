from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True, slots=True)
class GuardViolation:
    path: Path
    kind: str
    detail: str
