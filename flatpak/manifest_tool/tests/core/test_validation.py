"""Tests for validation operations."""

import pytest  # noqa: F401
from pathlib import Path
from manifest_tool.core import ManifestDocument, check_flathub_compliance


def test_check_flathub_compliance_clean_manifest():
    """Test compliance check passes for clean manifest."""
    doc = ManifestDocument(
        path=Path("test.yaml"),
        data={
            "app-id": "com.example.app",
            "runtime": "org.freedesktop.Platform",
            "finish-args": [
                "--share=network",  # This is allowed at runtime
                "--socket=wayland",
            ],
            "modules": [
                {
                    "name": "test-module",
                    "build-commands": [
                        "flutter pub get --offline",
                        "flutter build linux --no-pub",
                    ],
                }
            ],
        },
    )

    result = check_flathub_compliance(doc)
    assert result.success
    assert "passed" in result.message


def test_check_flathub_compliance_network_in_build_args():
    """Test compliance check catches --share=network in build-args."""
    doc = ManifestDocument(
        path=Path("test.yaml"),
        data={
            "app-id": "com.example.app",
            "modules": [
                {
                    "name": "test-module",
                    "build-options": {
                        "build-args": ["--share=network"]  # This is forbidden
                    },
                }
            ],
        },
    )

    result = check_flathub_compliance(doc)
    assert not result.success
    assert "--share=network in build-args" in str(result.details)


def test_check_flathub_compliance_network_in_finish_args_allowed():
    """Test that --share=network is allowed in finish-args (runtime)."""
    doc = ManifestDocument(
        path=Path("test.yaml"),
        data={
            "app-id": "com.example.app",
            "finish-args": [
                "--share=network",  # This should be allowed at runtime
                "--share=ipc",
            ],
            "modules": [{"name": "test-module", "build-commands": ["echo 'test'"]}],
        },
    )

    result = check_flathub_compliance(doc)
    assert result.success


def test_check_flathub_compliance_flutter_config():
    """Test compliance check catches flutter config commands."""
    doc = ManifestDocument(
        path=Path("test.yaml"),
        data={
            "app-id": "com.example.app",
            "modules": [
                {
                    "name": "test-module",
                    "build-commands": [
                        "flutter config --no-analytics",
                        "flutter build linux",
                    ],
                }
            ],
        },
    )

    result = check_flathub_compliance(doc)
    assert not result.success
    assert "flutter config command found" in str(result.details)


def test_check_flathub_compliance_pub_get_without_offline():
    """Test compliance check catches pub get without --offline."""
    doc = ManifestDocument(
        path=Path("test.yaml"),
        data={
            "app-id": "com.example.app",
            "modules": [
                {
                    "name": "test-module",
                    "build-commands": [
                        "flutter pub get",  # Missing --offline
                        "flutter build linux",
                    ],
                }
            ],
        },
    )

    result = check_flathub_compliance(doc)
    assert not result.success
    assert "'pub get' without --offline" in str(result.details)


def test_check_flathub_compliance_pub_get_with_offline():
    """Test compliance check passes for pub get with --offline."""
    doc = ManifestDocument(
        path=Path("test.yaml"),
        data={
            "app-id": "com.example.app",
            "modules": [
                {
                    "name": "test-module",
                    "build-commands": [
                        "flutter pub get --offline",
                        "dart pub get --offline --no-precompile",
                    ],
                }
            ],
        },
    )

    result = check_flathub_compliance(doc)
    assert result.success


def test_check_flathub_compliance_flutter_build_without_no_pub_warning():
    """Test compliance check warns about flutter build without --no-pub."""
    doc = ManifestDocument(
        path=Path("test.yaml"),
        data={
            "app-id": "com.example.app",
            "modules": [
                {
                    "name": "test-module",
                    "build-commands": [
                        "flutter pub get --offline",
                        "flutter build linux --release",  # Missing --no-pub
                    ],
                }
            ],
        },
    )

    result = check_flathub_compliance(doc)
    assert result.success  # Warnings don't fail the check
    assert "warning" in result.message.lower()
    assert "'flutter build' without --no-pub" in str(result.details)


def test_check_flathub_compliance_nested_modules():
    """Test compliance check works with nested modules."""
    doc = ManifestDocument(
        path=Path("test.yaml"),
        data={
            "app-id": "com.example.app",
            "modules": [
                {
                    "name": "parent-module",
                    "modules": [
                        {
                            "name": "child-module",
                            "build-options": {
                                "build-args": [
                                    "--share=network"
                                ]  # Forbidden in nested module
                            },
                            "build-commands": [
                                "flutter config --no-analytics",  # Also forbidden
                                "pub get",  # Missing --offline
                            ],
                        }
                    ],
                }
            ],
        },
    )

    result = check_flathub_compliance(doc)
    assert not result.success
    violations = str(result.details)
    assert "--share=network in build-args" in violations
    assert "flutter config command found" in violations
    assert "'pub get' without --offline" in violations


def test_check_flathub_compliance_multiple_violations():
    """Test compliance check reports all violations."""
    doc = ManifestDocument(
        path=Path("test.yaml"),
        data={
            "app-id": "com.example.app",
            "modules": [
                {
                    "name": "module1",
                    "build-options": {"build-args": ["--share=network"]},
                },
                {
                    "name": "module2",
                    "build-commands": [
                        "flutter config --no-analytics",
                        "pub get",
                        "flutter build linux",
                    ],
                },
            ],
        },
    )

    result = check_flathub_compliance(doc)
    assert not result.success
    violations = str(result.details)

    # Check all violations are reported
    assert "module1" in violations
    assert "module2" in violations
    assert "--share=network" in violations
    assert "flutter config" in violations
    assert "pub get" in violations
