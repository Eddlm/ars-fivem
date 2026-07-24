"""Fail on suspicious lowercase global accesses in compiled racingsystem Lua.

FiveM natives and ScaleformUI constructors use uppercase names. Accidental cross-module
calls in this resource have historically appeared as lowercase globals after calling a
later local function or omitting a RacingSystem.Server namespace. `luac -l -l` exposes
those `_ENV` reads without requiring luacheck or a C compiler.

Run from repository root: python .piTools/audit_lua_globals.py
"""

from __future__ import annotations

import re
import subprocess
from pathlib import Path

ALLOWED_LOWERCASE_GLOBALS = {
    "assert",
    "error",
    "ipairs",
    "io",
    "json",
    "math",
    "next",
    "os",
    "pairs",
    "pcall",
    "print",
    "rawget",
    "rawset",
    "select",
    "source",  # FiveM server event source.
    "string",
    "table",
    "tonumber",
    "tostring",
    "type",
    "utf8",
    "vector3",  # FiveM vector constructor/type.
    "xpcall",
}

GLOBAL_PATTERN = re.compile(r'_ENV "([^"]+)"')
failures: list[str] = []
compiled_files = 0
observed_globals: set[str] = set()

for path in sorted(Path("racingsystem").rglob("*.lua")):
    if path.name == "fxmanifest.lua":
        continue
    result = subprocess.run(
        ["luac", "-p", "-l", "-l", str(path)],
        check=True,
        capture_output=True,
        text=True,
        errors="replace",
    )
    compiled_files += 1
    globals_in_file = set(GLOBAL_PATTERN.findall(result.stdout))
    observed_globals.update(globals_in_file)
    for name in sorted(globals_in_file):
        if name[:1].islower() and name not in ALLOWED_LOWERCASE_GLOBALS:
            failures.append(f"{path}: suspicious lowercase global `{name}`")

if failures:
    raise SystemExit("\n".join(failures))

print(
    f"PASS: audited {compiled_files} compiled Lua files; "
    f"{len(observed_globals)} intentional/runtime globals, no suspicious lowercase access"
)
