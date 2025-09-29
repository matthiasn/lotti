"""Validation operations for Flatpak manifests.

This module provides validation checks to ensure Flatpak manifests comply with
Flathub requirements, particularly around network access restrictions during builds.
"""

from typing import List, Tuple, Optional
from dataclasses import dataclass, field

try:
    from .manifest import ManifestDocument
except ImportError:
    from manifest import ManifestDocument  # type: ignore


@dataclass
class ValidationResult:
    """Result of a validation check."""

    success: bool
    message: str
    details: Optional[List[str]] = field(default=None)


def check_flathub_compliance(document: ManifestDocument) -> ValidationResult:
    """
    Check manifest for Flathub compliance violations.

    Returns success if compliant, or error with list of violations.

    Checks performed:
    - No --share=network in build-args (forbidden at build time)
    - No flutter config commands (should not modify config during build)
    - All pub get commands use --offline flag
    - Flutter build commands preferably use --no-pub flag (warning only)
    """
    violations = []

    # Check for --share=network in build-args (forbidden at build time)
    violations.extend(_check_network_in_build_args(document.data))

    # Check for flutter config commands (should not modify config during build)
    violations.extend(_check_flutter_config_commands(document.data))

    # Check for pub get without --offline
    violations.extend(_check_pub_get_offline(document.data))

    # Check for flutter build without --no-pub (warning only)
    warnings = _check_flutter_build_no_pub(document.data)

    if violations:
        return ValidationResult(
            success=False,
            message="Flathub compliance violations found",
            details=violations,
        )

    result_msg = "Flathub compliance checks passed"
    if warnings:
        result_msg += f" (with {len(warnings)} warning(s))"
        return ValidationResult(success=True, message=result_msg, details=warnings)

    return ValidationResult(success=True, message=result_msg)


def _check_network_in_build_args(data: dict) -> List[str]:
    """Check for --share=network in build-args sections.

    Flathub strictly forbids network access during builds.
    The --share=network flag in build-args would violate this policy.

    Args:
        data: The manifest data dictionary

    Returns:
        List of violation descriptions
    """
    violations = []

    def check_module(module: dict, path: str):
        """Recursively check a module and its nested modules.

        Args:
            module: Module dictionary to check
            path: Path string for error reporting (e.g., "modules.lotti")
        """
        if "build-options" in module:
            build_opts = module["build-options"]
            if "build-args" in build_opts:
                build_args = build_opts["build-args"]
                if isinstance(build_args, list):
                    # Check each build argument for network sharing
                    for arg in build_args:
                        if arg == "--share=network":
                            violations.append(
                                f"{path}: --share=network in build-args (network forbidden during build)"
                            )

        # Check nested modules
        if "modules" in module:
            for i, submodule in enumerate(module["modules"]):
                if isinstance(submodule, dict):
                    name = submodule.get("name", f"module[{i}]")
                    check_module(submodule, f"{path}.modules.{name}")

    # Check top-level modules
    if "modules" in data:
        for i, module in enumerate(data["modules"]):
            if isinstance(module, dict):
                name = module.get("name", f"module[{i}]")
                check_module(module, f"modules.{name}")

    return violations


def _check_flutter_config_commands(data: dict) -> List[str]:
    """Check for flutter config commands in build-commands.

    Flutter config commands modify global Flutter state and should not
    be used during Flathub builds.

    Args:
        data: The manifest data dictionary

    Returns:
        List of violation descriptions
    """
    violations = []

    def check_commands(commands: List, path: str):
        """Check a list of build commands for flutter config usage.

        Args:
            commands: List of build command strings
            path: Path string for error reporting
        """
        for i, cmd in enumerate(commands):
            if isinstance(cmd, str) and "flutter" in cmd and "config" in cmd:
                # Use regex to match "flutter config" commands accurately
                # This avoids false positives like "configure_flutter"
                import re

                if re.search(r"flutter\s+config", cmd):
                    violations.append(
                        f"{path}[{i}]: flutter config command found (should not modify config during build)"
                    )

    def check_module(module: dict, path: str):
        """Recursively check a module."""
        if "build-commands" in module:
            check_commands(module["build-commands"], f"{path}.build-commands")

        if "modules" in module:
            for i, submodule in enumerate(module["modules"]):
                if isinstance(submodule, dict):
                    name = submodule.get("name", f"module[{i}]")
                    check_module(submodule, f"{path}.modules.{name}")

    if "modules" in data:
        for i, module in enumerate(data["modules"]):
            if isinstance(module, dict):
                name = module.get("name", f"module[{i}]")
                check_module(module, f"modules.{name}")

    return violations


def _check_pub_get_offline(data: dict) -> List[str]:
    """Check for pub get commands without --offline flag.

    The 'pub get' command needs the --offline flag to prevent
    network access during Flathub builds.

    Args:
        data: The manifest data dictionary

    Returns:
        List of violation descriptions
    """
    violations = []

    def check_commands(commands: List, path: str):
        """Check a list of build commands."""
        for i, cmd in enumerate(commands):
            if isinstance(cmd, str) and "pub get" in cmd:
                if "--offline" not in cmd:
                    violations.append(
                        f"{path}[{i}]: 'pub get' without --offline flag (network access forbidden)"
                    )

    def check_module(module: dict, path: str):
        """Recursively check a module."""
        if "build-commands" in module:
            check_commands(module["build-commands"], f"{path}.build-commands")

        if "modules" in module:
            for i, submodule in enumerate(module["modules"]):
                if isinstance(submodule, dict):
                    name = submodule.get("name", f"module[{i}]")
                    check_module(submodule, f"{path}.modules.{name}")

    if "modules" in data:
        for i, module in enumerate(data["modules"]):
            if isinstance(module, dict):
                name = module.get("name", f"module[{i}]")
                check_module(module, f"modules.{name}")

    return violations


def _check_flutter_build_no_pub(data: dict) -> List[str]:
    """Check for flutter build commands without --no-pub flag (warning only).

    Flutter build internally runs 'dart pub get --example' which can
    trigger network access. The --no-pub flag prevents this.
    This is a warning because builds may still work without it.

    Args:
        data: The manifest data dictionary

    Returns:
        List of warning descriptions
    """
    warnings = []

    def check_commands(commands: List, path: str):
        """Check a list of build commands."""
        for i, cmd in enumerate(commands):
            if isinstance(cmd, str) and "flutter build" in cmd:
                # Check if --no-pub flag is missing (best practice)
                if "--no-pub" not in cmd:
                    warnings.append(
                        f"Warning: {path}[{i}]: 'flutter build' without --no-pub flag (may trigger network access)"
                    )

    def check_module(module: dict, path: str):
        """Recursively check a module."""
        if "build-commands" in module:
            check_commands(module["build-commands"], f"{path}.build-commands")

        if "modules" in module:
            for i, submodule in enumerate(module["modules"]):
                if isinstance(submodule, dict):
                    name = submodule.get("name", f"module[{i}]")
                    check_module(submodule, f"{path}.modules.{name}")

    if "modules" in data:
        for i, module in enumerate(data["modules"]):
            if isinstance(module, dict):
                name = module.get("name", f"module[{i}]")
                check_module(module, f"modules.{name}")

    return warnings
