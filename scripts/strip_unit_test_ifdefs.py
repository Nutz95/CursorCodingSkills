#!/usr/bin/env python3
"""Strip #if(n)def UNIT_TEST branches from C/C++ sources.

Keeps the production (#ifndef UNIT_TEST / #if !defined(UNIT_TEST)) branch;
drops test-only (#ifdef UNIT_TEST) branches and matching #else stubs.
"""

from __future__ import annotations

import argparse
import re
from pathlib import Path

IF_UNIT = re.compile(r"^\s*#\s*if(n?)def\s+UNIT_TEST\b")
IF_DEFINED_UNIT = re.compile(
    r"^\s*#\s*if\s+(!\s*)?defined\s*\(\s*UNIT_TEST\s*\)\b"
)
IF_ANY = re.compile(r"^\s*#\s*if(n?def)?\b")
ELSE = re.compile(r"^\s*#\s*else\b")
ELIF = re.compile(r"^\s*#\s*elif\b")
ENDIF = re.compile(r"^\s*#\s*endif\b")


def strip_unit_test(text: str) -> str:
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    # ("unit", keep_branch, seen_else) | ("other", keep_passthrough, _)
    stack: list[tuple[str, bool, bool]] = []

    def emitting() -> bool:
        return all(item[1] for item in stack)

    for i, line in enumerate(lines, start=1):
        unit_match = IF_UNIT.match(line) or IF_DEFINED_UNIT.match(line)
        if unit_match:
            if IF_UNIT.match(line):
                negated = IF_UNIT.match(line).group(1) == "n"
            else:
                negated = bool(IF_DEFINED_UNIT.match(line).group(1))
            stack.append(("unit", negated, False))
            continue

        if ENDIF.match(line):
            if not stack:
                raise RuntimeError(f"{i}: #endif without open if")
            top = stack.pop()
            if top[0] == "other" and emitting():
                out.append(line)
            continue

        if ELSE.match(line):
            if not stack:
                raise RuntimeError(f"{i}: #else without open if")
            kind, keep, seen = stack[-1]
            if kind == "unit":
                if seen:
                    raise RuntimeError(f"{i}: double #else in UNIT_TEST block")
                stack[-1] = (kind, not keep, True)
            elif emitting():
                out.append(line)
            continue

        if ELIF.match(line):
            if stack and stack[-1][0] == "unit":
                raise RuntimeError(f"{i}: #elif in UNIT_TEST block not supported")
            if emitting():
                out.append(line)
            continue

        if IF_ANY.match(line):
            # Nested non-UNIT #if: inherit emit state for passthrough tracking.
            stack.append(("other", emitting(), False))
            if emitting():
                out.append(line)
            continue

        if emitting():
            out.append(line)

    if stack:
        raise RuntimeError(f"unclosed preprocessor stack: {stack}")
    return "".join(out)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("paths", nargs="+", type=Path)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()

    changed = 0
    for path in args.paths:
        original = path.read_text(encoding="utf-8")
        if "UNIT_TEST" not in original:
            continue
        updated = strip_unit_test(original)
        still = "UNIT_TEST" in updated
        if args.write:
            path.write_text(updated, encoding="utf-8", newline="\n")
            status = "WROTE"
        else:
            status = "WOULD WRITE"
        flag = " (STILL HAS UNIT_TEST)" if still else ""
        print(f"{status} {path}{flag}")
        changed += 1
    print(f"{changed} file(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
