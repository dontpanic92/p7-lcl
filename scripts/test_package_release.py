import importlib.util
from pathlib import Path
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "p7_lcl_package_release", ROOT / "scripts/package-release.py"
)
package_release = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(package_release)


class PackageReleaseTests(unittest.TestCase):
    def test_archive_is_deterministic_and_complete(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            library = root / "libp7lcl.dylib"
            library.write_bytes(b"test native extension")
            output_dir = root / "dist"

            first = package_release.package_target(
                "aarch64-apple-darwin", library, output_dir
            )
            first_bytes = first.read_bytes()
            second = package_release.package_target(
                "aarch64-apple-darwin", library, output_dir
            )
            self.assertEqual(first_bytes, second.read_bytes())

            with tarfile.open(second, "r:gz") as archive:
                names = {member.name for member in archive.getmembers()}
            self.assertIn("p7.toml", names)
            self.assertIn("src/mod.p7", names)
            self.assertIn("native/lib/libp7lcl.dylib", names)
            self.assertIn("LICENSE", names)
            self.assertIn("THIRD_PARTY_NOTICES.md", names)

    def test_index_contains_every_target_and_relative_urls(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            library = root / "extension"
            library.write_bytes(b"test native extension")
            for target in package_release.TARGET_LIBRARIES:
                package_release.package_target(target, library, root)

            index = package_release.generate_index(
                root, root / "release.index.toml", ""
            )
            contents = index.read_text(encoding="utf-8")
            for target in package_release.TARGET_LIBRARIES:
                self.assertIn(f'[targets."{target}"]', contents)
                self.assertIn(
                    f'url = "p7-lcl-{package_release.package_version()}-{target}.tar.gz"',
                    contents,
                )


if __name__ == "__main__":
    unittest.main()
