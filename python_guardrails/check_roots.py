from pathlib import Path

from python_guardrails.file_size_guard import FileSizeGuard
from python_guardrails.guard_violation import GuardViolation
from python_guardrails.python_structure_guard import PythonStructureGuard
from python_guardrails.python_typing_guard import PythonTypingGuard


def check_roots(
    size_roots: list[Path],
    python_roots: list[Path] | None = None,
    *,
    check_size: bool = True,
    check_structure: bool = True,
    check_typing: bool = True,
) -> list[GuardViolation]:
    """Run the standard SOLID guardrail set on the given roots."""
    py_roots = python_roots if python_roots is not None else size_roots
    violations: list[GuardViolation] = []
    if check_size:
        violations.extend(FileSizeGuard().check(size_roots))
    if check_structure:
        violations.extend(PythonStructureGuard().check(py_roots))
    if check_typing:
        violations.extend(PythonTypingGuard().check(py_roots))
    return violations


def format_violations(violations: list[GuardViolation]) -> str:
    return "\n".join(
        f"- {item.path}: {item.kind} ({item.detail})" for item in violations
    )


def assert_roots_clean(
    size_roots: list[Path],
    python_roots: list[Path] | None = None,
    *,
    check_size: bool = True,
    check_structure: bool = True,
    check_typing: bool = True,
) -> None:
    violations = check_roots(
        size_roots,
        python_roots,
        check_size=check_size,
        check_structure=check_structure,
        check_typing=check_typing,
    )
    if violations:
        raise AssertionError(
            "Guardrail violations:\n" + format_violations(violations)
        )
