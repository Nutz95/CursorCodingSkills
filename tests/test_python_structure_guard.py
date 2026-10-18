from pathlib import Path
import tempfile

from python_guardrails.python_structure_guard import PythonStructureGuard


def test_flags_multiple_types_and_variadic_tuple() -> None:
    guard = PythonStructureGuard()
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        sample = root / "bad_module.py"
        sample.write_text(
            "\n".join(
                [
                    "class Alpha:",
                    "    pass",
                    "",
                    "class Beta:",
                    "    pass",
                    "",
                    "def items() -> tuple[str, ...]:",
                    "    return ()",
                    "",
                    "def split_uid(raw: str) -> tuple[str, int]:",
                    "    return raw, 1",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        kinds = {item.kind for item in guard.check([root])}
        assert "one_type_per_file" in kinds
        assert "variadic_tuple" in kinds
        assert "tuple_return" in kinds


def test_flags_multiline_tuple_return() -> None:
    guard = PythonStructureGuard()
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        sample = root / "multiline.py"
        sample.write_text(
            "\n".join(
                [
                    "class Parser:",
                    "    def parse(",
                    "        self,",
                    "        payload: str,",
                    "    ) -> tuple[str, int]:",
                    "        return payload, 1",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        kinds = {item.kind for item in guard.check([root])}
        assert "tuple_return" in kinds


def test_flags_nested_class() -> None:
    guard = PythonStructureGuard()
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        sample = root / "nested.py"
        sample.write_text(
            "\n".join(
                [
                    "class Outer:",
                    "    class Inner:",
                    "        pass",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        kinds = {item.kind for item in guard.check([root])}
        assert "nested_class" in kinds


def test_allows_flask_response_tuple() -> None:
    guard = PythonStructureGuard()
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        sample = root / "flask_view.py"
        sample.write_text(
            "\n".join(
                [
                    "from flask import Response",
                    "",
                    "class DashboardController:",
                    "    def api_snapshot(self) -> Response | tuple[Response, int]:",
                    "        return Response(), 200",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        kinds = {item.kind for item in guard.check([root])}
        assert "tuple_return" not in kinds


if __name__ == "__main__":
    test_flags_multiple_types_and_variadic_tuple()
    test_flags_multiline_tuple_return()
    test_flags_nested_class()
    test_allows_flask_response_tuple()
    print("OK")
