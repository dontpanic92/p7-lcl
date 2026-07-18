#!/usr/bin/env python3

import argparse
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]

TARGETS = {
    "aarch64-apple-darwin": ("darwin", "aarch64", "cocoa", "libp7lcl.dylib"),
    "x86_64-apple-darwin": ("darwin", "x86_64", "cocoa", "libp7lcl.dylib"),
    "x86_64-unknown-linux-gnu": ("linux", "x86_64", "gtk3", "libp7lcl.so"),
    "x86_64-pc-windows-msvc": ("win64", "x86_64", "win32", "p7lcl.dll"),
}


def host_target() -> str:
    machine = platform.machine().lower()
    system = platform.system()
    if system == "Darwin" and machine in {"arm64", "aarch64"}:
        return "aarch64-apple-darwin"
    if system == "Darwin" and machine == "x86_64":
        return "x86_64-apple-darwin"
    if system == "Linux" and machine == "x86_64":
        return "x86_64-unknown-linux-gnu"
    if system == "Windows" and machine in {"amd64", "x86_64"}:
        return "x86_64-pc-windows-msvc"
    raise SystemExit(f"unsupported build host: {system} {machine}")


def find_lazbuild() -> Path:
    configured = os.environ.get("LAZBUILD")
    candidates = [
        Path(configured) if configured else None,
        Path(shutil.which("lazbuild")) if shutil.which("lazbuild") else None,
        Path.home() / "lazarus" / ("lazbuild.exe" if os.name == "nt" else "lazbuild"),
        Path("/Applications/Lazarus/lazbuild"),
        Path("/Applications/Lazarus.app/Contents/MacOS/lazbuild"),
    ]
    for candidate in candidates:
        if candidate and candidate.is_file():
            return candidate.resolve()
    raise SystemExit("cannot find lazbuild; set LAZBUILD to its full path")


def infer_lazarus_dir(lazbuild: Path):
    for candidate in (lazbuild.parent, *lazbuild.parents):
        if (candidate / "lcl").is_dir():
            return candidate
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description="Build the p7-lcl native extension")
    parser.add_argument("--target", choices=sorted(TARGETS), default=host_target())
    parser.add_argument("--build-all", action="store_true")
    args = parser.parse_args()

    target_os, target_cpu, widgetset, library_name = TARGETS[args.target]
    lazbuild = find_lazbuild()
    config = ROOT / "target" / "lazarus-config" / args.target
    config.mkdir(parents=True, exist_ok=True)
    (ROOT / "native" / "lib").mkdir(parents=True, exist_ok=True)

    subprocess.run([sys.executable, str(ROOT / "generator" / "generate.py")], check=True)

    command = [
        str(lazbuild),
        "--quiet",
        "--no-write-project",
        f"--primary-config-path={config}",
        f"--operating-system={target_os}",
        f"--cpu={target_cpu}",
        f"--widgetset={widgetset}",
    ]
    if args.build_all:
        command.append("--build-all")

    configured_lazarus_dir = os.environ.get("LAZARUS_DIR")
    lazarus_dir = (
        Path(configured_lazarus_dir)
        if configured_lazarus_dir
        else infer_lazarus_dir(lazbuild)
    )
    if lazarus_dir:
        command.append(f"--lazarusdir={lazarus_dir}")
    compiler = os.environ.get("FPC") or shutil.which("fpc")
    if compiler:
        command.append(f"--compiler={compiler}")
    if target_os == "darwin" and os.environ.get("P7_LCL_DARWIN_LD_CLASSIC", "1") != "0":
        command.append("--opt=-k-ld_classic")

    command.append(str(ROOT / "native" / "pascal" / "p7lcl.lpi"))
    subprocess.run(command, check=True)

    library = ROOT / "native" / "lib" / library_name
    if not library.is_file():
        raise SystemExit(f"lazbuild completed without producing {library}")
    shutil.copy2(library, ROOT / "native" / "lib" / "p7lcl.native")
    print(library)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
