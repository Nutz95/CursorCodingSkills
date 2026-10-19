from pathlib import Path
import tempfile

from python_guardrails.baseline_store import assert_within_baseline, write_baseline
from python_guardrails.dynamic_access_guard import DynamicAccessGuard
from python_guardrails.function_line_limit_guard import FunctionLineLimitGuard
from python_guardrails.inline_fake_class_guard import InlineFakeClassGuard
from python_guardrails.monkeypatch_setattr_guard import MonkeypatchSetattrGuard
from python_guardrails.nested_function_def_guard import NestedFunctionDefGuard
from python_guardrails.owned_positional_tuple_guard import OwnedPositionalTupleGuard


def test_dynamic_access_and_marker() -> None:
    guard = DynamicAccessGuard(skip_tests=False)
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        bad = root / "bad.py"
        bad.write_text(
            "\n".join(
                [
                    "def read(obj):",
                    "    return getattr(obj, 'x')",
                    "",
                    "def ok(obj):",
                    "    # solid-getattr: documented extension hook",
                    "    return getattr(obj, 'hook', None)",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        kinds = [item.kind for item in guard.check([root])]
        assert kinds.count("getattr_hasattr") == 1


def test_nested_def_guard() -> None:
    guard = NestedFunctionDefGuard(skip_tests=False)
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        sample = root / "nested.py"
        sample.write_text(
            "\n".join(
                [
                    "def outer():",
                    "    def inner():",
                    "        return 1",
                    "    return inner()",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        kinds = {item.kind for item in guard.check([root])}
        assert "nested_function_def" in kinds


def test_function_line_limit() -> None:
    guard = FunctionLineLimitGuard(max_lines=5, skip_tests=False)
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        sample = root / "long_fn.py"
        body = "\n".join([f"    x{i} = {i}" for i in range(8)])
        sample.write_text(f"def big():\n{body}\n    return 0\n", encoding="utf-8")
        kinds = {item.kind for item in guard.check([root])}
        assert "function_max_lines" in kinds


def test_owned_positional_tuple_guard() -> None:
    guard = OwnedPositionalTupleGuard(skip_tests=False)
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        sample = root / "tuples.py"
        sample.write_text(
            "\n".join(
                [
                    "from collections import namedtuple",
                    "from typing import NamedTuple",
                    "",
                    "Point = namedtuple('Point', ['x', 'y'])",
                    "",
                    "class Rect(NamedTuple):",
                    "    x: int",
                    "    y: int",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        kinds = {item.kind for item in guard.check([root])}
        assert "namedtuple_call" in kinds
        assert "namedtuple_class" in kinds


def test_inline_fake_and_monkeypatch() -> None:
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        tests = root / "tests"
        tests.mkdir()
        (tests / "test_sample.py").write_text(
            "\n".join(
                [
                    "class FakeClient:",
                    "    pass",
                    "",
                    "def test_x(monkeypatch):",
                    "    monkeypatch.setattr('os.getcwd', lambda: '/')",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        fake_kinds = {item.kind for item in InlineFakeClassGuard().check([root])}
        mp_kinds = {item.kind for item in MonkeypatchSetattrGuard().check([root])}
        assert "inline_fake_class" in fake_kinds
        assert "monkeypatch_setattr" in mp_kinds


def test_baseline_ratchet() -> None:
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        baseline = root / "baseline.json"
        write_baseline(baseline, {"getattr_hasattr": 1})
        from python_guardrails.guard_violation import GuardViolation

        violations = [
            GuardViolation(path=root / "a.py", kind="getattr_hasattr", detail="x"),
            GuardViolation(path=root / "b.py", kind="getattr_hasattr", detail="y"),
        ]
        try:
            assert_within_baseline(violations, baseline)
            raise AssertionError("expected baseline failure")
        except AssertionError as error:
            assert "getattr_hasattr" in str(error)


if __name__ == "__main__":
    test_dynamic_access_and_marker()
    test_nested_def_guard()
    test_function_line_limit()
    test_owned_positional_tuple_guard()
    test_inline_fake_and_monkeypatch()
    test_baseline_ratchet()
    print("OK")
