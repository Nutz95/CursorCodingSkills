from pathlib import Path
import tempfile

from python_guardrails.python_typing_guard import PythonTypingGuard


def test_flags_any_and_bare_dict() -> None:
    guard = PythonTypingGuard()
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        sample = root / "loose.py"
        sample.write_text(
            "\n".join(
                [
                    "from typing import Any",
                    "",
                    "class Loose:",
                    "    def handle(self, payload: object) -> Any:",
                    "        data: dict = {}",
                    "        return data",
                    "",
                ]
            ),
            encoding="utf-8",
        )
        kinds = {item.kind for item in guard.check([root])}
        assert "typing_any_import" in kinds
        assert "object_type" in kinds
        assert "any_type" in kinds
        assert "bare_dict" in kinds


def test_allows_runtime_list_constructor() -> None:
    guard = PythonTypingGuard()
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        sample = root / "ok.py"
        sample.write_text(
            "\n".join(
                [
                    "class Loader:",
                    "    def load(self) -> list[str]:",
                    '        return list({"a": 1}.keys())',
                    "",
                ]
            ),
            encoding="utf-8",
        )
        assert guard.check([root]) == []


def test_allows_frozen_object_setattr() -> None:
    guard = PythonTypingGuard()
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        sample = root / "frozen_model.py"
        sample.write_text(
            "\n".join(
                [
                    "from dataclasses import dataclass",
                    "",
                    "@dataclass(frozen=True, slots=True)",
                    "class Item:",
                    "    values: list[str]",
                    "",
                    "    def __post_init__(self) -> None:",
                    '        object.__setattr__(self, "values", list(self.values))',
                    "",
                ]
            ),
            encoding="utf-8",
        )
        assert guard.check([root]) == []


if __name__ == "__main__":
    test_flags_any_and_bare_dict()
    test_allows_runtime_list_constructor()
    test_allows_frozen_object_setattr()
    print("OK")
