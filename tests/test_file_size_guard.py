from pathlib import Path
import tempfile

from python_guardrails.file_size_guard import FileSizeGuard


def test_flags_oversized_file() -> None:
    guard = FileSizeGuard(max_lines=3)
    with tempfile.TemporaryDirectory() as folder:
        root = Path(folder)
        sample = root / "big.py"
        sample.write_text("a\nb\nc\nd\n", encoding="utf-8")
        violations = guard.check([root])
        assert len(violations) == 1
        assert violations[0].kind == "lines"


if __name__ == "__main__":
    test_flags_oversized_file()
    print("OK")
