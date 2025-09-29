"""Tests for offline build fixes."""

import pytest
from pathlib import Path
import sys
import tempfile

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

from manifest_tool.core.manifest import ManifestDocument
from manifest_tool.flutter import offline_fixes


def create_test_manifest():
    """Create a test manifest with common issues."""
    return {
        "app-id": "com.test.app",
        "modules": [
            {
                "name": "flutter-sdk",
                "sources": [
                    {"type": "git", "url": "https://github.com/flutter/flutter.git"},
                    {
                        "type": "file",
                        "path": "setup-flutter.sh",
                        "dest": "flutter/bin",
                        "dest-filename": "setup-flutter.sh",
                    },
                ],
            },
            {
                "name": "lotti",
                "build-options": {
                    "append-path": "/app/flutter/bin:/usr/bin",
                    "env": {
                        "PATH": "/app/flutter/bin:/usr/bin:/bin",
                        "PUB_CACHE": "/run/build/lotti/.pub-cache",
                    },
                },
                "build-commands": [
                    "echo Setting up Flutter SDK...",
                    "setup-flutter.sh -C /var/lib",
                    "cp -r /app/flutter /run/build/lotti/flutter_sdk",
                    "chmod -R u+w /run/build/lotti/flutter_sdk",
                    "/run/build/lotti/flutter_sdk/bin/flutter pub get --offline",
                ],
                "sources": [],
            },
        ],
    }


def test_remove_setup_flutter_command():
    """Test removal of setup-flutter.sh command."""
    doc = ManifestDocument(path=Path("test.yml"))
    doc.data = create_test_manifest()
    result = offline_fixes.remove_setup_flutter_command(doc)

    assert result.changed
    assert "Removed command: setup-flutter.sh -C /var/lib" in str(result.messages)

    # Check the command was removed
    lotti = next(m for m in doc.data["modules"] if m.get("name") == "lotti")
    commands = lotti["build-commands"]
    assert not any("setup-flutter.sh" in cmd for cmd in commands)
    assert "echo Setting up Flutter SDK..." in commands  # Other commands remain


def test_fix_flutter_sdk_paths():
    """Test fixing Flutter SDK paths from /app to /var/lib."""
    doc = ManifestDocument(path=Path("test.yml"))
    doc.data = create_test_manifest()
    result = offline_fixes.fix_flutter_sdk_paths(doc)

    assert result.changed
    assert "Fixed path in command" in str(result.messages)
    assert "Fixed PATH environment variable" in str(result.messages)
    assert "Fixed append-path" in str(result.messages)

    lotti = next(m for m in doc.data["modules"] if m.get("name") == "lotti")

    # Check build commands
    commands = lotti["build-commands"]
    assert any("cp -r /var/lib/flutter" in cmd for cmd in commands)
    assert not any("/app/flutter" in cmd for cmd in commands)

    # Check environment
    env = lotti["build-options"]["env"]
    assert "/var/lib/flutter/bin" in env["PATH"]
    assert "/app/flutter/bin" not in env["PATH"]

    # Check append-path
    assert "/var/lib/flutter/bin" in lotti["build-options"]["append-path"]
    assert "/app/flutter/bin" not in lotti["build-options"]["append-path"]


def test_remove_flutter_sdk_source():
    """Test removal of setup-flutter.sh source from flutter-sdk module."""
    doc = ManifestDocument(path=Path("test.yml"))
    doc.data = create_test_manifest()
    result = offline_fixes.remove_flutter_sdk_source(doc)

    assert result.changed
    assert "Removed setup-flutter.sh source from flutter-sdk" in str(result.messages)

    flutter_sdk = next(m for m in doc.data["modules"] if m.get("name") == "flutter-sdk")
    sources = flutter_sdk["sources"]
    assert not any(
        s.get("dest-filename") == "setup-flutter.sh"
        for s in sources
        if isinstance(s, dict)
    )


def test_apply_all_offline_fixes():
    """Test applying all fixes at once."""
    doc = ManifestDocument(path=Path("test.yml"))
    doc.data = create_test_manifest()
    result = offline_fixes.apply_all_offline_fixes(doc)

    assert result.changed
    assert len(result.messages) >= 3  # At least 3 types of fixes

    # Verify all fixes were applied
    lotti = next(m for m in doc.data["modules"] if m.get("name") == "lotti")
    flutter_sdk = next(m for m in doc.data["modules"] if m.get("name") == "flutter-sdk")

    # No setup-flutter.sh command
    commands = lotti["build-commands"]
    assert not any("setup-flutter.sh" in cmd for cmd in commands)

    # Paths are fixed
    assert any("/var/lib/flutter" in cmd for cmd in commands if isinstance(cmd, str))
    assert not any("/app/flutter" in cmd for cmd in commands if isinstance(cmd, str))

    # No setup-flutter.sh source
    sources = flutter_sdk["sources"]
    assert not any(
        s.get("dest-filename") == "setup-flutter.sh"
        for s in sources
        if isinstance(s, dict)
    )


def test_idempotency():
    """Test that running fixes multiple times doesn't cause issues."""
    doc = ManifestDocument(path=Path("test.yml"))
    doc.data = create_test_manifest()

    # Apply fixes once
    result1 = offline_fixes.apply_all_offline_fixes(doc)
    assert result1.changed

    # Apply again - should not change
    result2 = offline_fixes.apply_all_offline_fixes(doc)
    assert not result2.changed
    assert result2.messages == []


def test_ensure_rustup_in_path():
    """Test that rustup bin directory is added to PATH when rustup module exists."""
    doc = ManifestDocument(path=Path("test.yml"))
    doc.data = {
        "app-id": "com.test.app",
        "modules": [
            {"name": "flutter-sdk"},
            "rustup-1.83.0.json",  # Rustup module reference
            {
                "name": "lotti",
                "build-options": {
                    "append-path": "/var/lib/flutter/bin:/usr/bin",
                    "env": {
                        "PATH": "/usr/lib/sdk/rust-stable/bin:/var/lib/flutter/bin:/usr/bin:/bin",
                    },
                },
            },
        ],
    }

    result = offline_fixes.ensure_rustup_in_path(doc)
    assert result.changed
    assert "Added /var/lib/rustup/bin to PATH" in str(result.messages)
    assert "Added /var/lib/rustup/bin to append-path" in str(result.messages)
    assert "Set RUSTUP_HOME to /var/lib/rustup" in str(result.messages)

    lotti = next(
        m
        for m in doc.data["modules"]
        if isinstance(m, dict) and m.get("name") == "lotti"
    )
    env = lotti["build-options"]["env"]
    append_path = lotti["build-options"]["append-path"]

    # Check rustup bin is in PATH
    assert env["PATH"].startswith("/var/lib/rustup/bin:")
    assert "/var/lib/rustup/bin" in env["PATH"]

    # Check rustup bin is in append-path
    assert append_path.startswith("/var/lib/rustup/bin:")
    assert "/var/lib/rustup/bin" in append_path

    # Check RUSTUP_HOME is set correctly
    assert env["RUSTUP_HOME"] == "/var/lib/rustup"


def test_rustup_path_not_added_without_module():
    """Test that rustup PATH is not added when rustup module doesn't exist."""
    doc = ManifestDocument(path=Path("test.yml"))
    doc.data = {
        "app-id": "com.test.app",
        "modules": [
            {
                "name": "lotti",
                "build-options": {
                    "env": {
                        "PATH": "/usr/bin:/bin",
                    },
                },
            },
        ],
    }

    result = offline_fixes.ensure_rustup_in_path(doc)
    assert not result.changed

    lotti = next(
        m
        for m in doc.data["modules"]
        if isinstance(m, dict) and m.get("name") == "lotti"
    )
    env = lotti["build-options"]["env"]

    # PATH should be unchanged
    assert "/var/lib/rustup/bin" not in env["PATH"]


def test_rustup_path_idempotent():
    """Test that rustup PATH is not added twice."""
    doc = ManifestDocument(path=Path("test.yml"))
    doc.data = {
        "app-id": "com.test.app",
        "modules": [
            "rustup-1.83.0.json",
            {
                "name": "lotti",
                "build-options": {
                    "append-path": "/var/lib/rustup/bin:/var/lib/flutter/bin:/usr/bin",
                    "env": {
                        "PATH": "/var/lib/rustup/bin:/usr/lib/sdk/rust-stable/bin:/usr/bin:/bin",
                        "RUSTUP_HOME": "/var/lib/rustup",
                    },
                },
            },
        ],
    }

    result = offline_fixes.ensure_rustup_in_path(doc)
    assert not result.changed  # Should not change if already present

    lotti = next(
        m
        for m in doc.data["modules"]
        if isinstance(m, dict) and m.get("name") == "lotti"
    )
    env = lotti["build-options"]["env"]

    # Should have rustup bin only once
    assert env["PATH"].count("/var/lib/rustup/bin") == 1
    # RUSTUP_HOME should remain correct
    assert env["RUSTUP_HOME"] == "/var/lib/rustup"


def test_rustup_home_conflict_fix():
    """Test fixing RUSTUP_HOME conflict from SDK extension path."""
    doc = ManifestDocument(path=Path("test.yml"))
    doc.data = {
        "app-id": "com.test.app",
        "modules": [
            "rustup-1.83.0.json",
            {
                "name": "lotti",
                "build-options": {
                    "env": {
                        "PATH": "/usr/lib/sdk/rust-stable/bin:/usr/bin:/bin",
                        "RUSTUP_HOME": "/usr/lib/sdk/rust-stable",  # Wrong path
                    },
                },
            },
        ],
    }

    result = offline_fixes.ensure_rustup_in_path(doc)
    assert result.changed
    assert "Fixed RUSTUP_HOME to /var/lib/rustup" in str(result.messages)

    lotti = next(
        m
        for m in doc.data["modules"]
        if isinstance(m, dict) and m.get("name") == "lotti"
    )
    env = lotti["build-options"]["env"]

    # RUSTUP_HOME should be fixed to /var/lib/rustup
    assert env["RUSTUP_HOME"] == "/var/lib/rustup"
    # PATH should have rustup bin added
    assert env["PATH"].startswith("/var/lib/rustup/bin:")


def test_path_deduplication():
    """Test that duplicate paths are removed when fixing Flutter SDK paths."""
    doc = ManifestDocument(path=Path("test.yml"))
    doc.data = {
        "app-id": "com.test.app",
        "modules": [
            {
                "name": "lotti",
                "build-options": {
                    "env": {
                        # Path with both /app/flutter/bin and existing /var/lib/flutter/bin
                        "PATH": "/usr/bin:/app/flutter/bin:/var/lib/flutter/bin:/bin",
                    },
                },
            }
        ],
    }

    result = offline_fixes.fix_flutter_sdk_paths(doc)
    assert result.changed

    lotti = next(m for m in doc.data["modules"] if m.get("name") == "lotti")
    env = lotti["build-options"]["env"]

    # Should replace /app/flutter/bin with /var/lib/flutter/bin and deduplicate
    assert env["PATH"] == "/usr/bin:/var/lib/flutter/bin:/bin"
    # Check that /var/lib/flutter/bin appears only once
    assert env["PATH"].count("/var/lib/flutter/bin") == 1


def test_no_changes_needed():
    """Test when manifest doesn't need fixes."""
    doc = ManifestDocument(path=Path("test.yml"))
    doc.data = {
        "app-id": "com.test.app",
        "modules": [
            {
                "name": "lotti",
                "build-commands": [
                    "echo Building...",
                    "cp -r /var/lib/flutter /run/build/lotti/flutter_sdk",
                    "mkdir -p .cargo",
                    "ln -sfn ../cargo .cargo/cargo",
                    "cp cargo/config .cargo/config.toml 2>/dev/null || true",  # Already has cargo config copy
                ],
                "build-options": {
                    "env": {
                        "PATH": "/var/lib/flutter/bin:/usr/bin",
                        "CARGO_HOME": "/run/build/lotti/.cargo",  # Already set
                    },
                },
                "sources": [
                    # Already has cargokit patches
                    {
                        "type": "patch",
                        "path": "cargokit/run_build_tool.sh.patch",
                        "dest": ".pub-cache/hosted/pub.dev/super_native_extensions-0.9.1/cargokit",
                    },
                    {
                        "type": "patch",
                        "path": "cargokit/run_build_tool.sh.patch",
                        "dest": ".pub-cache/hosted/pub.dev/flutter_vodozemac-0.2.2/cargokit",
                    },
                    {
                        "type": "patch",
                        "path": "cargokit/run_build_tool.sh.patch",
                        "dest": ".pub-cache/hosted/pub.dev/irondash_engine_context-0.5.5/cargokit",
                    },
                    # Note: cargo config is provided by cargo-sources.json, not added manually
                ],
            }
        ],
    }

    result = offline_fixes.apply_all_offline_fixes(doc)
    assert not result.changed
    assert result.messages == []


def test_ensure_cargo_config_in_place():
    """Test that cargo config copy command is added and CARGO_HOME is set."""
    doc = ManifestDocument(path=Path("test.yml"))
    doc.data = {
        "app-id": "com.test.app",
        "modules": [
            {
                "name": "lotti",
                "build-commands": [
                    "echo Setting up Flutter SDK...",
                    "cp -r /var/lib/flutter /run/build/lotti/flutter_sdk",
                    "echo Building Lotti from source...",
                    "flutter pub get --offline",
                ],
            }
        ],
    }

    result = offline_fixes.ensure_cargo_config_in_place(doc)
    assert result.changed
    messages = " ".join(result.messages)
    assert "Added cargo config copy command" in messages
    assert "Ensured .cargo directory exists" in messages
    assert "Linked cargo vendor directory into CARGO_HOME" in messages
    assert "Set CARGO_HOME to /run/build/lotti/.cargo" in messages

    lotti = next(m for m in doc.data["modules"] if m.get("name") == "lotti")
    commands = lotti["build-commands"]

    # Should have the helper commands immediately after the build marker
    building_index = next(
        i for i, cmd in enumerate(commands) if "Building Lotti from source" in cmd
    )
    expected_commands = [
        "mkdir -p .cargo",
        "ln -sfn ../cargo .cargo/cargo",
        "cp cargo/config .cargo/config.toml 2>/dev/null || true",
    ]
    assert (
        commands[building_index + 1 : building_index + 1 + len(expected_commands)]
        == expected_commands
    )

    # Should have CARGO_HOME set
    assert lotti["build-options"]["env"]["CARGO_HOME"] == "/run/build/lotti/.cargo"


def test_cargo_config_copy_idempotent():
    """Test that cargo config copy command is not added twice."""
    doc = ManifestDocument(path=Path("test.yml"))
    doc.data = {
        "app-id": "com.test.app",
        "modules": [
            {
                "name": "lotti",
                "build-options": {
                    "env": {"CARGO_HOME": "/run/build/lotti/.cargo"}  # Already set
                },
                "build-commands": [
                    "echo Setting up Flutter SDK...",
                    "mkdir -p .cargo",
                    "ln -sfn ../cargo .cargo/cargo",
                    "cp cargo/config .cargo/config.toml 2>/dev/null || true",  # Already has it
                    "flutter pub get --offline",
                ],
            }
        ],
    }

    result = offline_fixes.ensure_cargo_config_in_place(doc)
    assert not result.changed

    lotti = next(m for m in doc.data["modules"] if m.get("name") == "lotti")
    commands = lotti["build-commands"]

    # Should only have one set of helper commands
    assert len([cmd for cmd in commands if "mkdir -p .cargo" in cmd]) == 1
    assert len([cmd for cmd in commands if "ln -sfn ../cargo .cargo/cargo" in cmd]) == 1
    assert (
        len([cmd for cmd in commands if "cp cargo/config .cargo/config.toml" in cmd])
        == 1
    )

    # CARGO_HOME should still be set
    assert lotti["build-options"]["env"]["CARGO_HOME"] == "/run/build/lotti/.cargo"


def test_cargo_home_environment_set():
    """Test that CARGO_HOME is set properly when not already present."""
    doc = ManifestDocument(path=Path("test.yml"))
    doc.data = {
        "app-id": "com.test.app",
        "modules": [
            {
                "name": "lotti",
                "build-options": {
                    "env": {
                        "PATH": "/usr/bin:/bin",
                        # No CARGO_HOME initially
                    }
                },
                "build-commands": [
                    "echo Building...",
                ],
            }
        ],
    }

    result = offline_fixes.ensure_cargo_config_in_place(doc)
    assert result.changed
    assert "Set CARGO_HOME to /run/build/lotti/.cargo" in str(result.messages)

    lotti = next(m for m in doc.data["modules"] if m.get("name") == "lotti")
    env = lotti["build-options"]["env"]

    # CARGO_HOME should be set
    assert env["CARGO_HOME"] == "/run/build/lotti/.cargo"


def test_cargo_home_not_changed_if_correct():
    """Test that CARGO_HOME is not changed if already set correctly."""
    doc = ManifestDocument(path=Path("test.yml"))
    doc.data = {
        "app-id": "com.test.app",
        "modules": [
            {
                "name": "lotti",
                "build-options": {
                    "env": {
                        "PATH": "/usr/bin:/bin",
                        "CARGO_HOME": "/run/build/lotti/.cargo",  # Already correct
                    }
                },
                "build-commands": [
                    "mkdir -p .cargo",
                    "ln -sfn ../cargo .cargo/cargo",
                    "cp cargo/config .cargo/config.toml 2>/dev/null || true",  # Has copy command
                ],
            }
        ],
    }

    result = offline_fixes.ensure_cargo_config_in_place(doc)
    assert not result.changed  # Should not change anything

    lotti = next(m for m in doc.data["modules"] if m.get("name") == "lotti")
    env = lotti["build-options"]["env"]

    # CARGO_HOME should remain unchanged
    assert env["CARGO_HOME"] == "/run/build/lotti/.cargo"


def test_comprehensive_offline_fixes():
    """Test that all offline fixes work together comprehensively."""
    doc = ManifestDocument(path=Path("test.yml"))
    doc.data = {
        "app-id": "com.test.app",
        "modules": [
            {
                "name": "flutter-sdk",
                "sources": [
                    {"type": "git", "url": "https://github.com/flutter/flutter.git"},
                    {
                        "type": "file",
                        "path": "setup-flutter.sh",
                        "dest": "flutter/bin",
                        "dest-filename": "setup-flutter.sh",
                    },
                ],
            },
            "rustup-1.83.0.json",  # Include rustup module
            {
                "name": "lotti",
                "build-commands": [
                    "echo Starting build...",
                    "setup-flutter.sh -C /var/lib",
                    "cp -r /app/flutter /run/build/lotti/flutter_sdk",
                ],
                "build-options": {
                    "append-path": "/app/flutter/bin:/usr/bin",
                    "env": {
                        "PATH": "/app/flutter/bin:/var/lib/flutter/bin:/usr/bin:/bin",
                        "RUSTUP_HOME": "/usr/lib/sdk/rust-stable",  # Wrong path
                    },
                },
                "sources": [
                    {"type": "file", "path": "some-file.txt"},
                    # One existing cargokit patch - should add the missing ones
                    {
                        "type": "patch",
                        "path": "cargokit/run_build_tool.sh.patch",
                        "dest": ".pub-cache/hosted/pub.dev/super_native_extensions-0.9.1/cargokit",
                    },
                ],
            },
        ],
    }

    result = offline_fixes.apply_all_offline_fixes(doc)
    assert result.changed

    # Check setup-flutter.sh was removed
    flutter_sdk = next(
        m
        for m in doc.data["modules"]
        if isinstance(m, dict) and m.get("name") == "flutter-sdk"
    )
    assert not any(
        s.get("dest-filename") == "setup-flutter.sh"
        for s in flutter_sdk["sources"]
        if isinstance(s, dict)
    )

    lotti = next(
        m
        for m in doc.data["modules"]
        if isinstance(m, dict) and m.get("name") == "lotti"
    )

    # Check setup-flutter.sh command was removed
    commands = lotti["build-commands"]
    assert not any("setup-flutter.sh" in cmd for cmd in commands)
    assert "echo Starting build..." in commands  # Other commands remain

    # Check paths are fixed and deduplicated
    env = lotti["build-options"]["env"]
    assert "/app/flutter/bin" not in env["PATH"]
    assert env["PATH"].count("/var/lib/flutter/bin") == 1
    # Rustup should be added to PATH
    assert env["PATH"].startswith("/var/lib/rustup/bin:")
    assert env["PATH"] == "/var/lib/rustup/bin:/var/lib/flutter/bin:/usr/bin:/bin"
    # RUSTUP_HOME should be fixed to /var/lib/rustup
    assert env["RUSTUP_HOME"] == "/var/lib/rustup"

    # Check append-path is fixed and has rustup
    assert (
        lotti["build-options"]["append-path"]
        == "/var/lib/rustup/bin:/var/lib/flutter/bin:/usr/bin"
    )

    # Check all cargokit patches are present
    sources = lotti["sources"]
    cargokit_patches = [
        s
        for s in sources
        if isinstance(s, dict)
        and s.get("type") == "patch"
        and "cargokit" in s.get("dest", "")
    ]
    assert len(cargokit_patches) == 3

    # Note: We don't add cargo config anymore - cargo-sources.json provides it


if __name__ == "__main__":
    # Run tests
    test_remove_setup_flutter_command()
    print("✓ test_remove_setup_flutter_command passed")

    test_fix_flutter_sdk_paths()
    print("✓ test_fix_flutter_sdk_paths passed")

    test_remove_flutter_sdk_source()
    print("✓ test_remove_flutter_sdk_source passed")

    test_apply_all_offline_fixes()
    print("✓ test_apply_all_offline_fixes passed")

    test_idempotency()
    print("✓ test_idempotency passed")

    test_ensure_rustup_in_path()
    print("✓ test_ensure_rustup_in_path passed")

    test_rustup_path_not_added_without_module()
    print("✓ test_rustup_path_not_added_without_module passed")

    test_rustup_path_idempotent()
    print("✓ test_rustup_path_idempotent passed")

    test_rustup_home_conflict_fix()
    print("✓ test_rustup_home_conflict_fix passed")

    test_path_deduplication()
    print("✓ test_path_deduplication passed")

    test_no_changes_needed()
    print("✓ test_no_changes_needed passed")

    test_ensure_cargo_config_in_place()
    print("✓ test_ensure_cargo_config_in_place passed")

    test_cargo_config_copy_idempotent()
    print("✓ test_cargo_config_copy_idempotent passed")

    test_cargo_home_environment_set()
    print("✓ test_cargo_home_environment_set passed")

    test_cargo_home_not_changed_if_correct()
    print("✓ test_cargo_home_not_changed_if_correct passed")

    test_comprehensive_offline_fixes()
    print("✓ test_comprehensive_offline_fixes passed")

    print("\n✓ All tests passed!")
