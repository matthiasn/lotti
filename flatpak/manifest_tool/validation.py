"""Validation operations for Flatpak manifests."""

from typing import List, Tuple, Optional
from dataclasses import dataclass, field
from .manifest import ManifestDocument


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
    """Check for --share=network in build-args sections."""
    violations = []

    def check_module(module: dict, path: str):
        """Recursively check a module and its nested modules."""
        if "build-options" in module:
            build_opts = module["build-options"]
            if "build-args" in build_opts:
                build_args = build_opts["build-args"]
                if isinstance(build_args, list):
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
    """Check for flutter config commands in build-commands."""
    violations = []

    def check_commands(commands: List, path: str):
        """Check a list of build commands."""
        for i, cmd in enumerate(commands):
            if isinstance(cmd, str) and "flutter" in cmd and "config" in cmd:
                # Simple heuristic - could be made more sophisticated
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
    """Check for pub get commands without --offline flag."""
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
    """Check for flutter build commands without --no-pub flag (warning only)."""
    warnings = []

    def check_commands(commands: List, path: str):
        """Check a list of build commands."""
        for i, cmd in enumerate(commands):
            if isinstance(cmd, str) and "flutter build" in cmd:
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
