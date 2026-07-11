import copy
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "p7_lcl_generator", ROOT / "generator/generate.py"
)
generator = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(generator)


class GeneratorTests(unittest.TestCase):
    def setUp(self) -> None:
        self.metadata = generator.load_metadata()

    def assert_invalid(self, metadata: dict, message: str) -> None:
        with self.assertRaisesRegex(generator.MetadataError, message):
            generator.validate_metadata(metadata)

    def test_checked_in_outputs_match_metadata(self) -> None:
        for path, contents in generator.render_outputs(self.metadata).items():
            self.assertEqual(path.read_text(encoding="utf-8"), contents)

    def test_generation_is_deterministic(self) -> None:
        first = generator.render_outputs(self.metadata)
        second = generator.render_outputs(copy.deepcopy(self.metadata))
        self.assertEqual(first, second)

    def test_generated_callbacks_are_emitted_and_registered(self) -> None:
        outputs = generator.render_outputs(self.metadata)
        callbacks = outputs[
            ROOT / "native/pascal/generated/callbacks.inc"
        ]
        registration = outputs[
            ROOT / "native/pascal/generated/registration.inc"
        ]
        self.assertIn("function GeneratedComponentSetName", callbacks)
        self.assertIn("@GeneratedComponentSetName", registration)
        self.assertIn("function GeneratedButtonSetOnClick", callbacks)
        self.assertIn("@GeneratedButtonSetOnClick", registration)
        self.assertIn("function GeneratedButtonCreate", callbacks)
        self.assertIn("@GeneratedButtonCreate", registration)
        self.assertIn("function GeneratedButtonFinalize", callbacks)
        self.assertIn("@GeneratedButtonFinalize", registration)
        self.assertIn("@GeneratedLabelFinalize", registration)
        self.assertIn("@GeneratedEditFinalize", registration)
        self.assertIn("@GeneratedPanelFinalize", registration)
        self.assertIn("@GeneratedFormSetOnShow", registration)
        self.assertIn("@GeneratedFormSetOnResize", registration)

    def test_duplicate_type_tag_is_rejected(self) -> None:
        metadata = copy.deepcopy(self.metadata)
        metadata["foreign_types"][1]["type_tag"] = metadata["foreign_types"][0][
            "type_tag"
        ]
        self.assert_invalid(metadata, "duplicate foreign type type_tag")

    def test_invalid_ownership_is_rejected(self) -> None:
        metadata = copy.deepcopy(self.metadata)
        button = next(
            item for item in metadata["foreign_types"] if item["p7_name"] == "Button"
        )
        button["owner_type"] = "MissingOwner"
        self.assert_invalid(metadata, "invalid owner_type")

    def test_unsupported_wire_type_is_rejected(self) -> None:
        metadata = copy.deepcopy(self.metadata)
        metadata["functions"][0]["params"] = [
            {"name": "value", "p7": "int", "native": "pointer"}
        ]
        self.assert_invalid(metadata, "unsupported wire type pointer")

    def test_inheritance_cycle_is_rejected(self) -> None:
        metadata = copy.deepcopy(self.metadata)
        root = metadata["foreign_types"][0]
        root["p7_base"] = "Panel"
        root["pascal_base"] = "TPanel"
        self.assert_invalid(metadata, "inheritance cycle")

    def test_unknown_widgetset_is_rejected(self) -> None:
        metadata = copy.deepcopy(self.metadata)
        metadata["defaults"]["availability"]["widgetsets"] = ["unknown"]
        self.assert_invalid(metadata, "unknown widgetsets")

    def test_unknown_generated_callback_function_is_rejected(self) -> None:
        metadata = copy.deepcopy(self.metadata)
        metadata["generated_callbacks"][0]["function"] = "missing_function"
        self.assert_invalid(metadata, "unknown function missing_function")


if __name__ == "__main__":
    unittest.main()
