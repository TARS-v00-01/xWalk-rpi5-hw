#!/usr/bin/env python3
"""Host-only tests for the authenticated xWalk licence workflow."""

from __future__ import annotations

import contextlib
import configparser
import datetime
import importlib.machinery
import importlib.util
import io
import json
import secrets
import stat
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "xWalkLicenseTool"
LOADER = importlib.machinery.SourceFileLoader("xwalk_license_tool", str(SCRIPT_PATH))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
if SPEC is None:
    raise RuntimeError("Cannot load xWalkLicenseTool")
MODULE = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = MODULE
LOADER.exec_module(MODULE)


class XWalkLicenseToolTest(unittest.TestCase):
    """Verify validation, authentication, output safety, and CLI secrecy."""

    def setUp(self) -> None:
        """Create one isolated project layout for each test."""
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.project_root = Path(self.temporary_directory.name)
        self.tool = MODULE.XWalkLicenseTool(self.project_root)
        self.variables = {
            "GEMINI_MODEL": "gemini-fake-model",
            "OPENAI_MODEL": "openai-fake-model",
        }

    def write_config(self, name: str, content: dict[str, str]) -> Path:
        """Write one test model-configuration fixture under the isolated directory."""
        path = self.project_root / name
        parser = configparser.ConfigParser(interpolation=None)
        parser.optionxform = str
        parser["models"] = content
        with path.open("w", encoding="utf-8") as output_file:
            parser.write(output_file)
        return path

    def test_committed_template_contains_only_model_variables(self) -> None:
        """The repository template cannot regain an API credential field."""
        template_path = (
            SCRIPT_PATH.parents[2]
            / "shell-agent"
            / "env-tool"
            / "license"
            / "xWalkLicense.cfg"
        )
        parser = configparser.ConfigParser(interpolation=None)
        parser.optionxform = str
        parser.read(template_path, encoding="utf-8")
        self.assertEqual(parser.sections(), ["models"])
        values = dict(parser.items("models", raw=True))
        self.assertEqual(
            set(values),
            {
                "ANTHROPIC_MODEL",
                "GEMINI_MODEL",
                "OLLAMA_MODEL",
                "OPENAI_MODEL",
                "XWALK_AI_MODEL",
            },
        )
        self.assertTrue(all(value == "" for value in values.values()))

    def test_loads_valid_variables_from_config(self) -> None:
        """A models configuration section with string values is accepted."""
        path = self.write_config("valid.cfg", self.variables)
        self.assertEqual(self.tool.load_config_variables(path), self.variables)

    def test_loads_repeated_environment_arguments(self) -> None:
        """Repeated NAME=VALUE entries retain values containing equals signs."""
        loaded = self.tool.load_environment_arguments(
            ["OPENAI_MODEL=fake=value", "GEMINI_MODEL=gemini-fake"]
        )
        self.assertEqual(loaded["OPENAI_MODEL"], "fake=value")
        self.assertEqual(loaded["GEMINI_MODEL"], "gemini-fake")

    def test_rejects_empty_model_section(self) -> None:
        """The configuration must contain at least one model variable."""
        with self.assertRaisesRegex(MODULE.XWalkLicenseError, "no model"):
            self.tool.load_config_variables(self.write_config("empty.cfg", {}))

    def test_rejects_empty_model_values_without_printing_them(self) -> None:
        """Every selected variable must contain a non-empty value."""
        path = self.write_config(
            "empty-values.cfg", {"OPENAI_MODEL": "", "GEMINI_MODEL": ""}
        )
        with self.assertRaisesRegex(
            MODULE.XWalkLicenseError,
            "GEMINI_MODEL and OPENAI_MODEL contain empty values",
        ):
            self.tool.load_config_variables(path)

    def test_rejects_unexpected_configuration_section(self) -> None:
        """Only the case-sensitive models section is accepted."""
        path = self.project_root / "unexpected.cfg"
        path.write_text("[credentials]\nOPENAI_MODEL = fake-model\n", encoding="utf-8")
        with self.assertRaisesRegex(MODULE.XWalkLicenseError, "only one.*models"):
            self.tool.load_config_variables(path)

    def test_rejects_malformed_config(self) -> None:
        """Malformed configuration produces a safe message without echoing input."""
        path = self.project_root / "malformed.cfg"
        path.write_text("OPENAI_MODEL = fake-model\n", encoding="utf-8")
        with self.assertRaisesRegex(MODULE.XWalkLicenseError, "malformed"):
            self.tool.load_config_variables(path)

    def test_rejects_invalid_environment_variable_name(self) -> None:
        """Names must follow the portable process-environment syntax."""
        with self.assertRaisesRegex(MODULE.XWalkLicenseError, "invalid"):
            self.tool.load_environment_arguments(["INVALID-NAME=fake-secret"])

    def test_rejects_duplicate_environment_argument_names(self) -> None:
        """Repeated names cannot silently replace earlier command-line values."""
        with self.assertRaisesRegex(MODULE.XWalkLicenseError, "duplicate"):
            self.tool.load_environment_arguments(
                ["OPENAI_MODEL=first-fake", "OPENAI_MODEL=second-fake"]
            )

    def test_rejects_credentials_from_config_and_environment_arguments(self) -> None:
        """API credentials must be supplied only through the developer netrc file."""
        path = self.write_config("credential.cfg", {"OPENAI_API_KEY": "fake-secret"})
        with self.assertRaisesRegex(MODULE.XWalkLicenseError, "~/.netrc"):
            self.tool.load_config_variables(path)
        with self.assertRaisesRegex(MODULE.XWalkLicenseError, "~/.netrc"):
            self.tool.load_environment_arguments(["OPENAI_API_KEY=fake-secret"])

    def test_rejects_user_supplied_serial_number(self) -> None:
        """Callers cannot replace the serial generated for this encryption."""
        variables = dict(self.variables)
        variables[self.tool.SERIAL_VARIABLE_NAME] = "XWALK-2026-A7F3C92D"
        with self.assertRaisesRegex(MODULE.XWalkLicenseError, "generated automatically"):
            self.tool.encrypt(variables)

    def test_encrypts_and_decrypts_successfully(self) -> None:
        """Authenticated round-trip recovers the original fake values."""
        result = self.tool.encrypt(self.variables)
        output_path = self.project_root / "decrypted.json"
        recovered = self.tool.decrypt(result.decryption_key, output_path)
        expected = dict(self.variables)
        expected[self.tool.SERIAL_VARIABLE_NAME] = result.serial_number
        self.assertEqual(recovered, expected)
        self.assertEqual(json.loads(output_path.read_text(encoding="utf-8")), expected)

    def test_serial_uses_utc_year_and_secure_random_hex(self) -> None:
        """One generated serial is retained in the authenticated payload."""
        with mock.patch.object(MODULE.secrets, "token_hex", return_value="a7f3c92d") as token_hex:
            result = self.tool.encrypt(self.variables)
        current_year = datetime.datetime.now(datetime.timezone.utc).year
        expected_serial = f"XWALK-{current_year}-A7F3C92D"
        self.assertEqual(result.serial_number, expected_serial)
        token_hex.assert_called_once_with(4)
        recovered = self.tool.decrypt(
            result.decryption_key, self.project_root / "serial.json"
        )
        self.assertEqual(recovered[self.tool.SERIAL_VARIABLE_NAME], expected_serial)

    def test_each_encryption_uses_a_fresh_nonce(self) -> None:
        """Identical plaintext produces different encrypted file content."""
        self.tool.encrypt(self.variables)
        first_content = self.tool.license_path.read_bytes()
        self.tool.encrypt(self.variables)
        second_content = self.tool.license_path.read_bytes()
        self.assertNotEqual(first_content, second_content)
        nonce_start = len(self.tool.MAGIC_HEADER)
        nonce_end = nonce_start + MODULE.SecretBox.NONCE_SIZE
        self.assertNotEqual(
            first_content[nonce_start:nonce_end], second_content[nonce_start:nonce_end]
        )

    def test_decryption_fails_with_incorrect_key(self) -> None:
        """A different 256-bit key cannot authenticate the payload."""
        self.tool.encrypt(self.variables)
        wrong_key = secrets.token_bytes(32).hex()
        with self.assertRaisesRegex(MODULE.XWalkLicenseError, "incorrect.*modified"):
            self.tool.decrypt(wrong_key, self.project_root / "wrong.json")

    def test_decryption_fails_when_encrypted_content_is_modified(self) -> None:
        """A changed ciphertext or authenticator is rejected."""
        result = self.tool.encrypt(self.variables)
        content = bytearray(self.tool.license_path.read_bytes())
        content[-1] ^= 1
        self.tool.license_path.write_bytes(content)
        with self.assertRaisesRegex(MODULE.XWalkLicenseError, "incorrect.*modified"):
            self.tool.decrypt(result.decryption_key, self.project_root / "modified.json")

    def test_magic_header_and_fixed_output_path(self) -> None:
        """The output uses the version header and xWalkLibrary location."""
        self.tool.encrypt(self.variables)
        expected_path = (
            self.project_root / "xWalk-rpi5-hw" / "xWalkLibrary" / "X_WALK_LICENSE.KEY"
        )
        self.assertEqual(self.tool.license_path, expected_path)
        self.assertTrue(expected_path.read_bytes().startswith(b"XWL1"))

    def test_default_project_root_comes_from_script_location(self) -> None:
        """Normal operation never depends on the caller's working directory."""
        expected_root = (
            SCRIPT_PATH.parents[4]
            if SCRIPT_PATH.parents[2].name == "integration"
            else SCRIPT_PATH.parents[3]
        )
        self.assertEqual(MODULE.XWalkLicenseTool().project_root, expected_root)

    def test_decrypted_output_has_owner_only_permissions(self) -> None:
        """Plaintext JSON is always replaced with mode 0600."""
        result = self.tool.encrypt(self.variables)
        output_path = self.project_root / "permissions.json"
        output_path.write_text("old", encoding="utf-8")
        output_path.chmod(0o666)
        self.tool.decrypt(result.decryption_key, output_path)
        self.assertEqual(stat.S_IMODE(output_path.stat().st_mode), 0o600)

    def test_cli_output_does_not_reveal_values_and_prints_key_once(self) -> None:
        """Normal and error output disclose names but no plaintext values."""
        standard_output = io.StringIO()
        error_output = io.StringIO()
        with mock.patch.object(MODULE, "XWalkLicenseTool", return_value=self.tool):
            with mock.patch.object(MODULE.secrets, "token_hex", return_value="a7f3c92d"):
                with contextlib.redirect_stdout(standard_output):
                    with contextlib.redirect_stderr(error_output):
                        status = MODULE.main(
                            [
                                "encrypt",
                                "--env",
                                "OPENAI_MODEL=openai-fake-model",
                                "--env",
                                "GEMINI_MODEL=gemini-fake-model",
                            ]
                        )
        combined_output = standard_output.getvalue() + error_output.getvalue()
        self.assertEqual(status, 0)
        self.assertNotIn("openai-fake-model", combined_output)
        self.assertNotIn("gemini-fake-model", combined_output)
        current_year = datetime.datetime.now(datetime.timezone.utc).year
        serial_number = f"XWALK-{current_year}-A7F3C92D"
        expected_prefix = (
            "xWalk licence created successfully.\n\n"
            f"Encrypted licence file:\n{self.tool.license_path}\n\n"
            f"Licence serial number:\n{serial_number}\n\n"
            "Decryption key:\n"
        )
        self.assertTrue(standard_output.getvalue().startswith(expected_prefix))
        key = standard_output.getvalue()[len(expected_prefix) :].strip()
        self.assertEqual(standard_output.getvalue(), f"{expected_prefix}{key}\n")
        self.assertEqual(standard_output.getvalue().count(key), 1)
        recovered = self.tool.decrypt(key, self.project_root / "cli-output.json")
        self.assertEqual(recovered[self.tool.SERIAL_VARIABLE_NAME], serial_number)

        standard_output = io.StringIO()
        error_output = io.StringIO()
        with mock.patch.object(MODULE, "XWalkLicenseTool", return_value=self.tool):
            with contextlib.redirect_stdout(standard_output):
                with contextlib.redirect_stderr(error_output):
                    status = MODULE.main(
                        [
                            "encrypt",
                            "--env",
                            "OPENAI_MODEL=first-fake-model",
                            "--env",
                            "OPENAI_MODEL=second-fake-model",
                        ]
                    )
        combined_output = standard_output.getvalue() + error_output.getvalue()
        self.assertEqual(status, 2)
        self.assertNotIn("first-fake-model", combined_output)
        self.assertNotIn("second-fake-model", combined_output)

    def test_write_failure_prints_neither_serial_nor_decryption_key(self) -> None:
        """Generated metadata remains hidden unless encrypted output is durable."""
        standard_output = io.StringIO()
        error_output = io.StringIO()
        with mock.patch.object(MODULE, "XWalkLicenseTool", return_value=self.tool):
            with mock.patch.object(
                self.tool,
                "_write_private_file",
                side_effect=MODULE.XWalkLicenseError("simulated write failure"),
            ):
                with contextlib.redirect_stdout(standard_output):
                    with contextlib.redirect_stderr(error_output):
                        status = MODULE.main(
                            ["encrypt", "--env", "OPENAI_MODEL=fake-model"]
                        )
        self.assertEqual(status, 2)
        self.assertEqual(standard_output.getvalue(), "")
        self.assertNotIn("XWALK-", error_output.getvalue())
        self.assertNotIn("Decryption key", error_output.getvalue())


if __name__ == "__main__":
    unittest.main()
