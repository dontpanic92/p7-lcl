#!/usr/bin/env python3

import argparse
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def default_library() -> Path:
    system = platform.system()
    if system == "Darwin":
        name = "libp7lcl.dylib"
    elif system == "Linux":
        name = "libp7lcl.so"
    elif system == "Windows":
        name = "p7lcl.dll"
    else:
        raise SystemExit(f"unsupported host platform: {system}")
    return ROOT / "native" / "lib" / name


def find_program(environment: str, names, fallbacks=()):
    configured = os.environ.get(environment)
    if configured:
        return configured
    for name in names:
        found = shutil.which(name)
        if found:
            return found
    for fallback in fallbacks:
        if Path(fallback).is_file():
            return str(fallback)
    raise SystemExit(f"cannot find {names[0]}; set {environment}")


def run(command, **kwargs):
    subprocess.run([str(item) for item in command], check=True, **kwargs)


def main() -> int:
    parser = argparse.ArgumentParser(description="Check the p7 native extension ABI")
    parser.add_argument("--library", type=Path, default=default_library())
    args = parser.parse_args()
    library = args.library.resolve()
    if not library.is_file():
        raise SystemExit(f"native extension does not exist: {library}")

    cc = find_program("CC", ["cc", "clang", "gcc"])
    fpc = find_program("FPC", ["fpc"], ["/usr/local/bin/fpc"])
    executable_suffix = ".exe" if os.name == "nt" else ""

    with tempfile.TemporaryDirectory(prefix="p7-lcl-abi-") as temp:
        temp_dir = Path(temp)
        abi_compat = temp_dir / f"abi_compat{executable_suffix}"
        compile_command = [
            cc,
            "-std=c11",
            "-Wall",
            "-Wextra",
            "-Werror",
            f"-I{ROOT / 'protosept' / 'p7' / 'include'}",
            ROOT / "native" / "tests" / "abi_compat.c",
            "-o",
            abi_compat,
        ]
        if platform.system() == "Linux":
            compile_command.append("-ldl")
        run(compile_command)
        run([abi_compat, library])

        run(
            [
                fpc,
                f"-Fu{ROOT / 'native' / 'pascal'}",
                f"-FU{temp_dir}",
                f"-FE{temp_dir}",
                "-oabi_layout",
                ROOT / "native" / "tests" / "abi_layout.pas",
            ],
            stdout=subprocess.DEVNULL,
        )
        run([temp_dir / f"abi_layout{executable_suffix}"])

    cargo = find_program("CARGO", ["cargo"])
    common = [
        cargo,
        "test",
        "--quiet",
        "--manifest-path",
        ROOT / "protosept" / "Cargo.toml",
        "-p",
        "p7",
        "--test",
        "native_extension_abi",
    ]
    run([*common, "abi_layout_matches_c_contract"])
    run([*common, "native_function_descriptor_struct_size"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
