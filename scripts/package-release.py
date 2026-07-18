#!/usr/bin/env python3

import argparse
import gzip
import hashlib
from pathlib import Path, PurePosixPath
import re
import shutil
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]

TARGET_LIBRARIES = {
    "aarch64-apple-darwin": "libp7lcl.dylib",
    "x86_64-apple-darwin": "libp7lcl.dylib",
    "x86_64-unknown-linux-gnu": "libp7lcl.so",
    "x86_64-pc-windows-msvc": "p7lcl.dll",
}


def package_version() -> str:
    manifest = (ROOT / "p7.toml").read_text(encoding="utf-8")
    match = re.search(r'(?m)^version = "([^"]+)"$', manifest)
    if not match:
        raise SystemExit("p7.toml does not declare a package version")
    return match.group(1)


def staged_manifest(version: str, library_name: str) -> str:
    return (
        '[package]\n'
        'name = "lcl"\n'
        f'version = "{version}"\n'
        'kind = "library"\n\n'
        '[native]\n'
        f'extensions = ["native/lib/{library_name}"]\n'
    )


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_deterministic_tar_gz(source: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as raw:
        with gzip.GzipFile(fileobj=raw, mode="wb", filename="", mtime=0) as zipped:
            with tarfile.open(fileobj=zipped, mode="w", format=tarfile.GNU_FORMAT) as archive:
                for path in sorted(item for item in source.rglob("*") if item.is_file()):
                    relative = path.relative_to(source).as_posix()
                    info = tarfile.TarInfo(relative)
                    info.size = path.stat().st_size
                    info.mode = 0o644
                    info.mtime = 0
                    info.uid = 0
                    info.gid = 0
                    info.uname = ""
                    info.gname = ""
                    with path.open("rb") as contents:
                        archive.addfile(info, contents)


def verify_archive(path: Path, target: str, version: str) -> None:
    expected_library = f"native/lib/{TARGET_LIBRARIES[target]}"
    required = {
        "p7.toml",
        "src/mod.p7",
        "LICENSE",
        "THIRD_PARTY_NOTICES.md",
        expected_library,
    }
    with tarfile.open(path, "r:gz") as archive:
        members = archive.getmembers()
        names = set()
        for member in members:
            member_path = PurePosixPath(member.name)
            if (
                member_path.is_absolute()
                or ".." in member_path.parts
                or member.issym()
                or member.islnk()
            ):
                raise SystemExit(f"unsafe release archive member: {member.name}")
            if not member.isfile():
                raise SystemExit(f"release archive contains non-file member: {member.name}")
            if member.name in names:
                raise SystemExit(f"duplicate release archive member: {member.name}")
            names.add(member.name)
        missing = sorted(required - names)
        if missing:
            raise SystemExit(f"release archive is missing: {', '.join(missing)}")
        manifest_file = archive.extractfile("p7.toml")
        if manifest_file is None:
            raise SystemExit("release archive p7.toml is unreadable")
        manifest = manifest_file.read().decode("utf-8")
        if manifest != staged_manifest(version, TARGET_LIBRARIES[target]):
            raise SystemExit("release archive has unexpected p7.toml contents")


def package_target(target: str, library: Path, output_dir: Path) -> Path:
    version = package_version()
    library_name = TARGET_LIBRARIES[target]
    if not library.is_file():
        raise SystemExit(f"native extension does not exist: {library}")

    with tempfile.TemporaryDirectory(prefix="p7-lcl-package-") as temp:
        stage = Path(temp)
        (stage / "native" / "lib").mkdir(parents=True)
        shutil.copytree(ROOT / "src", stage / "src")
        shutil.copy2(ROOT / "LICENSE", stage / "LICENSE")
        shutil.copy2(
            ROOT / "THIRD_PARTY_NOTICES.md", stage / "THIRD_PARTY_NOTICES.md"
        )
        shutil.copy2(library, stage / "native" / "lib" / library_name)
        (stage / "p7.toml").write_text(
            staged_manifest(version, library_name), encoding="utf-8"
        )

        output = output_dir / f"p7-lcl-{version}-{target}.tar.gz"
        write_deterministic_tar_gz(stage, output)

    verify_archive(output, target, version)
    checksum = sha256(output)
    output.with_suffix(output.suffix + ".sha256").write_text(
        f"{checksum}  {output.name}\n", encoding="ascii"
    )
    print(output)
    return output


def generate_index(archives: Path, output: Path, base_url: str) -> Path:
    version = package_version()
    lines = [
        "version = 1",
        "",
        "[package]",
        'name = "lcl"',
        f'version = "{version}"',
        "",
        "[dependencies]",
    ]
    for target in TARGET_LIBRARIES:
        archive = archives / f"p7-lcl-{version}-{target}.tar.gz"
        if not archive.is_file():
            raise SystemExit(f"missing release archive: {archive}")
        verify_archive(archive, target, version)
        url = f"{base_url.rstrip('/')}/{archive.name}" if base_url else archive.name
        lines.extend(
            [
                "",
                f'[targets."{target}"]',
                f'url = "{url}"',
                f'sha256 = "{sha256(archive)}"',
                'format = "tar.gz"',
            ]
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    checksum = sha256(output)
    output.with_suffix(output.suffix + ".sha256").write_text(
        f"{checksum}  {output.name}\n", encoding="ascii"
    )
    print(output)
    return output


def main() -> int:
    parser = argparse.ArgumentParser(description="Package p7-lcl release artifacts")
    subparsers = parser.add_subparsers(dest="command", required=True)

    package_parser = subparsers.add_parser("package")
    package_parser.add_argument("--target", required=True, choices=TARGET_LIBRARIES)
    package_parser.add_argument("--library", type=Path)
    package_parser.add_argument("--output-dir", type=Path, default=ROOT / "dist")

    index_parser = subparsers.add_parser("index")
    index_parser.add_argument("--archives", type=Path, default=ROOT / "dist")
    index_parser.add_argument("--output", type=Path)
    index_parser.add_argument("--base-url", default="")

    verify_parser = subparsers.add_parser("verify")
    verify_parser.add_argument("--target", required=True, choices=TARGET_LIBRARIES)
    verify_parser.add_argument("archive", type=Path)

    args = parser.parse_args()
    if args.command == "package":
        library = args.library or ROOT / "native" / "lib" / TARGET_LIBRARIES[args.target]
        package_target(args.target, library, args.output_dir)
    elif args.command == "index":
        version = package_version()
        output = args.output or args.archives / f"p7-lcl-{version}.index.toml"
        generate_index(args.archives, output, args.base_url)
    else:
        verify_archive(args.archive, args.target, package_version())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
