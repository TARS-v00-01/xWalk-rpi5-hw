#!/usr/bin/env python3
"""Deterministic host tests for the xWalk dependency installer."""

from __future__ import annotations

import importlib.machinery
import importlib.util
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


SCRIPT_PATH = pathlib.Path(__file__).resolve()
GIT_ROOT = pathlib.Path(
    subprocess.run(
        ["git", "-C", str(SCRIPT_PATH.parent), "rev-parse", "--show-toplevel"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout.strip()
).resolve()
if (GIT_ROOT / "scripts/integration").is_dir():
    REPOSITORY_ROOT = GIT_ROOT
    TOOL_ROOT = GIT_ROOT / "scripts/integration"
elif (GIT_ROOT / "xWalk-rpi5-tool").is_dir():
    REPOSITORY_ROOT = GIT_ROOT
    TOOL_ROOT = GIT_ROOT / "xWalk-rpi5-tool"
else:
    REPOSITORY_ROOT = GIT_ROOT.parent
    TOOL_ROOT = GIT_ROOT
INSTALLER_PATH = TOOL_ROOT / "py-agent/dev-tool/xHal_Rpi5CarDependencyInstaller"
LOADER = importlib.machinery.SourceFileLoader("xwalk_dependency_installer", str(INSTALLER_PATH))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
if SPEC is None:
    raise RuntimeError("unable to create the dependency-installer module specification")
INSTALLER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = INSTALLER
LOADER.exec_module(INSTALLER)


class DependencyInstallerTest(unittest.TestCase):
    """Verify manifest coverage and boot-configuration safety logic."""

    def test_catalog_covers_every_hal_module(self) -> None:
        """Every independently configurable xWalkHal module must occur in a reporting group."""
        catalog = INSTALLER.parse_catalog(TOOL_ROOT / "apt-packages.txt")
        mapped_modules = {
            module
            for modules in catalog.groups.values()
            for module in modules
            if module.startswith("xWalk")
        }
        source_modules = {
            path.name
            for path in (REPOSITORY_ROOT / "xWalk-rpi5-hw" / "xWalkHal").iterdir()
            if path.is_dir()
            and path.name.startswith("xWalk")
            and (path / "CMakeLists.txt").is_file()
        }
        self.assertTrue(source_modules.issubset(mapped_modules))

    def test_catalog_declares_pynacl_for_supported_linux_families(self) -> None:
        """The licence tool dependency must be part of normal host and RPi setup."""
        catalog = INSTALLER.parse_catalog(
            TOOL_ROOT / "apt-packages.txt"
        )
        pynacl = next(
            package for package in catalog.packages if package.identifier == "pynacl"
        )
        self.assertEqual(pynacl.scope, "required")
        self.assertEqual(pynacl.targets, ("host", "rpi"))
        self.assertEqual(pynacl.packages["apt"], ("python3-nacl",))
        self.assertEqual(pynacl.packages["dnf"], ("python3-pynacl",))
        self.assertEqual(pynacl.packages["pacman"], ("python-pynacl",))

    def test_project_managed_vosk_matches_native_architecture(self) -> None:
        """The bundled Vosk check must select the normalized architecture prefix."""
        with mock.patch.object(INSTALLER.platform, "machine", return_value="AMD64"):
            installed, issue = INSTALLER.vosk_status(REPOSITORY_ROOT)
        self.assertTrue(installed)
        self.assertIn("project-managed Vosk", issue)

    def test_project_managed_vosk_rejects_unsupported_architecture(self) -> None:
        """A target without a reviewed native runtime must not be reported as ready."""
        with mock.patch.object(INSTALLER.platform, "machine", return_value="armv7l"):
            installed, issue = INSTALLER.vosk_status(REPOSITORY_ROOT)
        self.assertFalse(installed)
        self.assertIn("no Vosk runtime", issue)

    def test_boot_parser_ignores_commented_settings(self) -> None:
        """Commented settings must not satisfy or conflict with active settings."""
        lines = INSTALLER.active_boot_lines(
            "# dtparam=i2c_arm=off\n"
            "dtparam=i2c_arm=on # retained\n"
            "# dtoverlay=sunfounder-servohat+\n"
            "dtoverlay=sunfounder-robothat5\n"
        )
        self.assertTrue(INSTALLER.has_setting(lines, "i2c_arm", "on"))
        self.assertFalse(INSTALLER.has_setting(lines, "i2c_arm", "off"))
        self.assertTrue(INSTALLER.has_overlay(lines, "sunfounder-robothat5"))
        self.assertFalse(INSTALLER.has_overlay(lines, "sunfounder-servohat+"))

    def test_boot_settings_must_be_in_global_section(self) -> None:
        """A model-specific setting must not be treated as a global xWalk setting."""
        config_text = "[cm4]\ndtparam=spi=on\n[all]\ndtparam=i2c_arm=on\n"
        lines = INSTALLER.global_boot_lines(config_text)
        self.assertTrue(INSTALLER.has_setting(lines, "i2c_arm", "on"))
        self.assertFalse(INSTALLER.has_setting(lines, "spi", "on"))

    def test_current_boot_rows_accept_expected_configuration(self) -> None:
        """The expected blob and three active settings must pass passive validation."""
        source_overlay = TOOL_ROOT / "shell-agent/env-tool/dtoverlays/sunfounder-robothat5.dtbo"
        with tempfile.TemporaryDirectory(prefix="xwalk-dependency-test-") as directory:
            temporary_directory = pathlib.Path(directory)
            config_path = temporary_directory / "config.txt"
            overlay_path = temporary_directory / "sunfounder-robothat5.dtbo"
            config_path.write_text(
                "dtparam=i2c_arm=on\n"
                "dtparam=spi=on\n"
                "dtoverlay=sunfounder-robothat5\n",
                encoding="utf-8",
            )
            shutil.copyfile(source_overlay, overlay_path)
            rows = INSTALLER.current_boot_rows(config_path, overlay_path)
        self.assertTrue(all(row.installed for row in rows))

    def test_robot_hat_v4_overlay_is_refused(self) -> None:
        """The Servo HAT+ blob must never be substituted for Robot HAT v4."""
        platform_selection = INSTALLER.PlatformSelection("raspbian", "debian", "apt")
        with mock.patch.object(INSTALLER, "is_raspberry_pi", return_value=True):
            rows = INSTALLER.configure_raspberry_pi_boot(
                "dry-run", "robot_hat_v4", platform_selection, REPOSITORY_ROOT
            )
        self.assertEqual(len(rows), 1)
        self.assertFalse(rows[0].installed)
        self.assertIn("no verified Robot HAT v4 overlay", rows[0].issue)


if __name__ == "__main__":
    unittest.main()
