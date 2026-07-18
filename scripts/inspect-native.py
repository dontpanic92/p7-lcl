#!/usr/bin/env python3

import argparse
from pathlib import Path
import platform
import shutil
import subprocess


def main() -> int:
    parser = argparse.ArgumentParser(description="Print native extension dependencies")
    parser.add_argument("library", type=Path)
    args = parser.parse_args()
    library = args.library.resolve()
    if not library.is_file():
        raise SystemExit(f"native extension does not exist: {library}")

    system = platform.system()
    if system == "Darwin":
        command = ["otool", "-L", library]
    elif system == "Linux":
        command = ["ldd", library]
    elif system == "Windows":
        dumpbin = shutil.which("dumpbin")
        llvm_objdump = shutil.which("llvm-objdump")
        if dumpbin:
            command = [dumpbin, "/DEPENDENTS", library]
        elif llvm_objdump:
            command = [llvm_objdump, "-p", library]
        else:
            raise SystemExit("cannot find dumpbin or llvm-objdump")
    else:
        raise SystemExit(f"unsupported host platform: {system}")

    subprocess.run([str(item) for item in command], check=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
