#!/usr/bin/env python3

import argparse
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def run(command):
    subprocess.run([str(item) for item in command], check=True)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Test p7-lcl as a downloaded dependency"
    )
    parser.add_argument("index", type=Path)
    args = parser.parse_args()
    index = args.index.resolve()
    if index.is_dir():
        indexes = list(index.glob("p7-lcl-*.index.toml"))
        if len(indexes) != 1:
            raise SystemExit(
                f"expected one p7-lcl index in {index}, found {len(indexes)}"
            )
        index = indexes[0]
    if not index.is_file():
        raise SystemExit(f"artifact index does not exist: {index}")

    with tempfile.TemporaryDirectory(prefix="p7-lcl-consumer-") as temp:
        package = Path(temp)
        (package / "src").mkdir()
        (package / "tests").mkdir()
        (package / "p7.toml").write_text(
            '[package]\n'
            'name = "p7_lcl_release_consumer"\n'
            'version = "0.1.0"\n'
            'kind = "executable"\n\n'
            '[dependencies]\n'
            f'lcl = {{ index = "{index.as_uri()}" }}\n',
            encoding="utf-8",
        )
        (package / "src" / "main.p7").write_text(
            "fn main() -> int { 0 }\n", encoding="utf-8"
        )
        (package / "tests" / "test_release.p7").write_text(
            "import test.test;\n"
            "import lcl;\n\n"
            '@test(expected_type = "string", expected_value = "prebuilt")\n'
            "fn test_prebuilt_extension() -> string {\n"
            "  lcl.initialize();\n"
            "  let form = lcl.new_form();\n"
            '  lcl.set_form_caption(form, "prebuilt");\n'
            "  let result = lcl.form_caption(form);\n"
            "  lcl.free_form(form);\n"
            "  result\n"
            "}\n",
            encoding="utf-8",
        )

        cli = [
            "cargo",
            "run",
            "--quiet",
            "--manifest-path",
            ROOT / "protosept" / "Cargo.toml",
            "-p",
            "p7-cli",
            "--",
        ]
        run([*cli, "check", package])
        run([*cli, "build", package])
        run([*cli, "test", package])
        lockfile = (package / "p7.lock").read_text(encoding="utf-8")
        if "index_sha256" not in lockfile or "[package.source.targets" not in lockfile:
            raise SystemExit("downstream lockfile does not contain artifact integrity pins")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
