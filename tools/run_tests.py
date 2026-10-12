"""Run portable Lua tests, plus optional tests against locally extracted game GUI."""
import argparse
from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
GAME_TESTS = {
    "test_real_react_entry.lua",
    "test_real_react_settings.lua",
    "test_real_react_flash.lua",
    "test_real_react_lifecycle.lua",
    "test_branch_connections.lua",
}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", default="lua")
    parser.add_argument("--luac", default=shutil.which("luac"))
    parser.add_argument("--game-gui", type=Path)
    args = parser.parse_args()
    if not shutil.which(args.lua):
        parser.error("Lua executable not found; install Lua 5.4 or specify --lua /path/to/lua")
    if args.luac and not shutil.which(args.luac):
        parser.error("luac executable not found: " + args.luac)
    gui = args.game_gui.resolve() if args.game_gui else None
    if gui:
        for file in (gui / "react.lua", gui / "stylesheetutil.lua", gui / "../../scripts/mat4.tl"):
            if not file.is_file():
                parser.error("Missing required game file: " + str(file))
    passed = failed = skipped = 0
    for path in sorted((ROOT / "tests").glob("test_*.lua")):
        if path.name in GAME_TESTS and not gui:
            print("SKIP " + path.name + " (requires --game-gui)", flush=True)
            skipped += 1
            continue
        command = [args.lua, str(path.relative_to(ROOT))]
        if path.name in GAME_TESTS:
            command.append(str(gui if path.name == "test_branch_connections.lua" else gui / "react.lua"))
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        if result.returncode:
            failed += 1
            print("FAIL " + path.name + "\n" + result.stdout + result.stderr, flush=True)
        else:
            passed += 1
            print("PASS " + path.name, flush=True)
    syntax = 0
    if args.luac:
        for path in sorted((ROOT / "mod").rglob("*.lua")) + sorted((ROOT / "tests").glob("*.lua")):
            result = subprocess.run([args.luac, "-p", str(path)], cwd=ROOT, capture_output=True, text=True)
            if result.returncode:
                failed += 1
                print("FAIL syntax " + str(path.relative_to(ROOT)) + "\n" + result.stderr, flush=True)
            else:
                syntax += 1
    else:
        print("SKIP syntax (luac not found)", flush=True)
    print(f"{passed} passed, {failed} failed, {skipped} skipped; {syntax} syntax checks passed", flush=True)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
