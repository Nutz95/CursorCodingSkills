from pathlib import Path

from python_guardrails import assert_roots_clean


def test_package_is_clean() -> None:
    root = Path(__file__).resolve().parents[1]
    package = root / "python_guardrails"
    assert_roots_clean([package], [package])


if __name__ == "__main__":
    test_package_is_clean()
    print("OK")
