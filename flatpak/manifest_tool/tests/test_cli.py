from __future__ import annotations

import yaml

from flatpak.manifest_tool import cli
from pathlib import Path
import json
from flatpak.manifest_tool.tests.conftest import SAMPLE_MANIFEST


def test_cli_normalize_lotti_env(manifest_file, capsys):
    exit_code = cli.main(
        [
            "normalize-lotti-env",
            "--manifest",
            str(manifest_file),
            "--layout",
            "top",
            "--append-path",
        ]
    )

    assert exit_code == 0
    captured = capsys.readouterr()
    assert "Normalized lotti PATH" in captured.out

    data = yaml.safe_load(manifest_file.read_text(encoding="utf-8"))
    lotti = next(module for module in data["modules"] if module["name"] == "lotti")
    assert lotti["build-options"]["env"]["PATH"].startswith("/app/flutter/bin")


def test_cli_bundle_archive_sources(tmp_path, capsys):
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(SAMPLE_MANIFEST, encoding="utf-8")

    cache_root = tmp_path / "cache"
    cache_root.mkdir()
    (cache_root / "archive.tar.gz").write_text("data", encoding="utf-8")
    (cache_root / "helper.dat").write_text("data", encoding="utf-8")

    exit_code = cli.main(
        [
            "bundle-archive-sources",
            "--manifest",
            str(manifest_path),
            "--output-dir",
            str(tmp_path / "out"),
            "--search-root",
            str(cache_root),
        ]
    )

    assert exit_code == 0
    captured = capsys.readouterr()
    assert "BUNDLE archive.tar.gz" in captured.out

    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    lotti = next(module for module in data["modules"] if module["name"] == "lotti")
    archive_source = next(
        source
        for source in lotti["sources"]
        if isinstance(source, dict) and source.get("type") == "archive"
    )
    assert archive_source.get("path") == "archive.tar.gz"
    assert "url" not in archive_source


def test_cli_pin_commit(tmp_path, capsys):
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(SAMPLE_MANIFEST, encoding="utf-8")

    exit_code = cli.main(
        [
            "pin-commit",
            "--manifest",
            str(manifest_path),
            "--commit",
            "abc123",
        ]
    )

    assert exit_code == 0
    captured = capsys.readouterr()
    assert "Pinned lotti module" in captured.out

    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    lotti = next(module for module in data["modules"] if module["name"] == "lotti")
    commits = [
        source.get("commit") for source in lotti["sources"] if isinstance(source, dict)
    ]
    assert "abc123" in commits


def test_cli_remove_rustup_sources(tmp_path):
    # Build a manifest embedding rustup JSON under lotti sources
    data = yaml.safe_load(SAMPLE_MANIFEST)
    for module in data["modules"]:
        if module.get("name") == "lotti":
            module.setdefault("sources", []).extend(
                [
                    "rustup-1.83.0.json",
                    {"type": "file", "path": "rustup-1.83.0.json"},
                ]
            )
            break
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(yaml.safe_dump(data), encoding="utf-8")

    exit_code = cli.main(
        [
            "remove-rustup-sources",
            "--manifest",
            str(manifest_path),
        ]
    )

    assert exit_code == 0
    new_data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    lotti = next(module for module in new_data["modules"] if module["name"] == "lotti")
    sources = lotti["sources"]
    assert "rustup-1.83.0.json" not in [s for s in sources if isinstance(s, str)]
    assert not any(
        isinstance(s, dict) and s.get("path") == "rustup-1.83.0.json" for s in sources
    )


def test_cli_ensure_module_include_before_lotti(tmp_path):
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(SAMPLE_MANIFEST, encoding="utf-8")

    mod_name = "rustup-1.83.0.json"
    exit_code = cli.main(
        [
            "ensure-module-include",
            "--manifest",
            str(manifest_path),
            "--name",
            mod_name,
            "--before",
            "lotti",
        ]
    )
    assert exit_code == 0

    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    modules = data["modules"]
    idx_mod = next(i for i, m in enumerate(modules) if m == mod_name)
    idx_lotti = next(
        i
        for i, m in enumerate(modules)
        if isinstance(m, dict) and m.get("name") == "lotti"
    )
    assert idx_mod < idx_lotti


def test_cli_replace_url_with_path(tmp_path):
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(
        """
modules:
  - name: lotti
    sources:
      - type: file
        url: https://example.com/file.dat
""",
        encoding="utf-8",
    )

    exit_code = cli.main(
        [
            "replace-url-with-path",
            "--manifest",
            str(manifest_path),
            "--identifier",
            "file.dat",
            "--path",
            "file.dat",
        ]
    )
    assert exit_code == 0
    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    source = data["modules"][0]["sources"][0]
    assert source.get("path") == "file.dat"
    assert "url" not in source


def test_cli_ensure_setup_helper(tmp_path):
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(SAMPLE_MANIFEST, encoding="utf-8")
    exit_code = cli.main(
        [
            "ensure-setup-helper",
            "--manifest",
            str(manifest_path),
            "--helper",
            "setup-flutter.sh",
        ]
    )
    assert exit_code == 0
    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    flutter = next(m for m in data["modules"] if m.get("name") == "flutter-sdk")
    assert any(
        isinstance(s, dict)
        and s.get("type") == "file"
        and s.get("path") == "setup-flutter.sh"
        and s.get("dest") == "flutter/bin"
        for s in flutter.get("sources", [])
    )
    lotti = next(m for m in data["modules"] if m.get("name") == "lotti")
    assert lotti["build-options"]["env"]["PATH"].startswith("/app/flutter/bin")


def test_cli_ensure_lotti_setup_helper_idempotent(tmp_path):
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(SAMPLE_MANIFEST, encoding="utf-8")
    for _ in range(2):
        assert (
            cli.main(
                [
                    "ensure-lotti-setup-helper",
                    "--manifest",
                    str(manifest_path),
                    "--layout",
                    "top",
                    "--helper",
                    "setup-flutter.sh",
                ]
            )
            == 0
        )
    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    lotti = next(m for m in data["modules"] if m.get("name") == "lotti")
    cmds = lotti.get("build-commands", [])
    assert sum(1 for c in cmds if "setup-flutter.sh" in c) == 1


def test_cli_ensure_lotti_setup_helper(tmp_path):
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(SAMPLE_MANIFEST, encoding="utf-8")
    exit_code = cli.main(
        [
            "ensure-lotti-setup-helper",
            "--manifest",
            str(manifest_path),
            "--layout",
            "top",
            "--helper",
            "setup-flutter.sh",
        ]
    )
    assert exit_code == 0
    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    lotti = next(m for m in data["modules"] if m.get("name") == "lotti")
    cmds = lotti.get("build-commands", [])
    assert any("setup-flutter.sh" in c for c in cmds)


def test_cli_add_offline_sources(tmp_path):
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(SAMPLE_MANIFEST, encoding="utf-8")
    exit_code = cli.main(
        [
            "add-offline-sources",
            "--manifest",
            str(manifest_path),
            "--pubspec",
            "pubspec-sources.json",
            "--cargo",
            "cargo-sources.json",
            "--flutter-json",
            "flutter-sdk-3.35.4.json",
        ]
    )
    assert exit_code == 0
    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    lotti = next(m for m in data["modules"] if m.get("name") == "lotti")
    assert "pubspec-sources.json" in lotti["sources"]
    assert "cargo-sources.json" in lotti["sources"]
    assert any(
        isinstance(s, dict) and s.get("path") == "flutter-sdk-3.35.4.json"
        for s in lotti["sources"]
    )


def test_cli_normalize_lotti_env_idempotent(tmp_path):
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(SAMPLE_MANIFEST, encoding="utf-8")
    for _ in range(2):
        assert (
            cli.main(
                [
                    "normalize-lotti-env",
                    "--manifest",
                    str(manifest_path),
                    "--layout",
                    "top",
                    "--append-path",
                ]
            )
            == 0
        )
    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    lotti = next(m for m in data["modules"] if m.get("name") == "lotti")
    env_path = lotti["build-options"]["env"]["PATH"]
    parts = [p for p in env_path.split(":") if p]
    # /app/flutter/bin appears only once at the beginning
    assert parts[0] == "/app/flutter/bin"
    assert parts.count("/app/flutter/bin") == 1


def test_cli_ensure_rust_sdk_env(tmp_path):
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(SAMPLE_MANIFEST, encoding="utf-8")
    exit_code = cli.main(
        [
            "ensure-rust-sdk-env",
            "--manifest",
            str(manifest_path),
        ]
    )
    assert exit_code == 0
    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    lotti = next(m for m in data["modules"] if m.get("name") == "lotti")
    env_path = lotti["build-options"]["env"]["PATH"]
    assert env_path.startswith("/var/lib/rustup/bin")
    assert "/usr/lib/sdk/rust-stable/bin" in env_path


def test_cli_ensure_rust_sdk_env_idempotent(tmp_path):
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(SAMPLE_MANIFEST, encoding="utf-8")
    for _ in range(2):
        assert cli.main(["ensure-rust-sdk-env", "--manifest", str(manifest_path)]) == 0
    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    lotti = next(m for m in data["modules"] if m.get("name") == "lotti")
    env_path = lotti["build-options"]["env"]["PATH"]
    parts = [p for p in env_path.split(":") if p]
    assert parts[0] == "/var/lib/rustup/bin"
    assert parts[1] == "/usr/lib/sdk/rust-stable/bin"
    # No duplicates
    assert parts.count("/var/lib/rustup/bin") == 1
    assert parts.count("/usr/lib/sdk/rust-stable/bin") == 1


def test_cli_remove_network_from_build_args(tmp_path):
    """Test the remove-network-from-build-args CLI command."""
    data = yaml.safe_load(SAMPLE_MANIFEST)

    # Add --share=network to modules
    for module in data["modules"]:
        if isinstance(module, dict) and module.get("name") == "flutter-sdk":
            module.setdefault("build-options", {})["build-args"] = ["--share=network"]
        elif isinstance(module, dict) and module.get("name") == "lotti":
            module["build-options"]["build-args"] = ["--share=network", "--allow=devel"]

    manifest_path = tmp_path / "test.yml"
    manifest_path.write_text(yaml.safe_dump(data), encoding="utf-8")

    exit_code = cli.main(
        ["remove-network-from-build-args", "--manifest", str(manifest_path)]
    )

    assert exit_code == 0
    updated = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))

    # Check --share=network removed from flutter-sdk
    flutter_sdk = next(
        m
        for m in updated["modules"]
        if isinstance(m, dict) and m.get("name") == "flutter-sdk"
    )
    assert "--share=network" not in flutter_sdk.get("build-options", {}).get(
        "build-args", []
    )

    # Check --share=network removed from lotti but other args remain
    lotti = next(
        m
        for m in updated["modules"]
        if isinstance(m, dict) and m.get("name") == "lotti"
    )
    assert "--share=network" not in lotti["build-options"]["build-args"]
    assert "--allow=devel" in lotti["build-options"]["build-args"]


def test_cli_remove_rustup_install(tmp_path):
    data = yaml.safe_load(SAMPLE_MANIFEST)
    for module in data["modules"]:
        if module.get("name") == "lotti":
            module["build-commands"] = [
                "echo Installing Rust...",
                "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal",
                'export PATH="$HOME/.cargo/bin:$PATH"',
                "echo done",
            ]
            break
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(yaml.safe_dump(data), encoding="utf-8")
    exit_code = cli.main(
        [
            "remove-rustup-install",
            "--manifest",
            str(manifest_path),
        ]
    )
    assert exit_code == 0
    new_data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    cmds = next(m for m in new_data["modules"] if m.get("name") == "lotti")[
        "build-commands"
    ]
    assert all("rustup" not in c and "cargo/bin" not in c for c in cmds)


def test_cli_pr_aware_pin(tmp_path, capsys):
    # Create a minimal PR event payload
    payload = {
        "pull_request": {
            "head": {
                "sha": "deadbeef",
                "ref": "feature/x",
                "repo": {"clone_url": "https://github.com/user/repo.git"},
            }
        }
    }
    event_path = tmp_path / "event.json"
    event_path.write_text(json.dumps(payload), encoding="utf-8")

    exit_code = cli.main(
        [
            "pr-aware-pin",
            "--event-name",
            "pull_request",
            "--event-path",
            str(event_path),
        ]
    )
    assert exit_code == 0
    out = capsys.readouterr().out
    # Parse assignments, tolerate optional quoting of values
    pairs = [line.split("=", 1) for line in out.strip().splitlines() if "=" in line]
    assigns = {k: v for k, v in pairs}
    assert assigns.get("PR_MODE") == "true"
    sha = assigns.get("PR_HEAD_SHA", "").strip("'\"")
    assert sha == "deadbeef"


def test_cli_ensure_module_include_idempotent(tmp_path):
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(SAMPLE_MANIFEST, encoding="utf-8")
    for _ in range(2):
        assert (
            cli.main(
                [
                    "ensure-module-include",
                    "--manifest",
                    str(manifest_path),
                    "--name",
                    "rustup-1.83.0.json",
                    "--before",
                    "lotti",
                ]
            )
            == 0
        )
    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    mods = data["modules"]
    assert sum(1 for m in mods if m == "rustup-1.83.0.json") == 1


def test_cli_remove_rustup_sources_global(tmp_path):
    data = yaml.safe_load(SAMPLE_MANIFEST)
    # Inject rustup under both flutter-sdk and lotti sources
    for module in data["modules"]:
        module.setdefault("sources", []).extend(
            [
                "rustup-1.83.0.json",
                {"type": "file", "path": "rustup-1.83.0.json"},
            ]
        )
    manifest_path = tmp_path / "manifest.yml"
    manifest_path.write_text(yaml.safe_dump(data), encoding="utf-8")
    assert cli.main(["remove-rustup-sources", "--manifest", str(manifest_path)]) == 0
    new = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    for module in new["modules"]:
        sources = module.get("sources", [])
        assert "rustup-1.83.0.json" not in [s for s in sources if isinstance(s, str)]
        assert not any(
            isinstance(s, dict) and s.get("path") == "rustup-1.83.0.json"
            for s in sources
        )


def test_cli_generate_setup_helper(tmp_path):
    """Test generate-setup-helper command."""
    output_path = tmp_path / "test-helper.sh"

    exit_code = cli.main(["generate-setup-helper", "--output", str(output_path)])

    assert exit_code == 0
    assert output_path.exists()

    # Check that it's executable
    import stat

    file_stat = output_path.stat()
    assert file_stat.st_mode & stat.S_IXUSR  # User execute permission

    # Check content starts with shebang
    content = output_path.read_text(encoding="utf-8")
    assert content.startswith("#!/bin/bash")
    assert "setup-flutter.sh" in content or "Flutter SDK" in content


def test_cli_find_flutter_sdk(tmp_path):
    """Test find-flutter-sdk command."""
    # Create a fake Flutter SDK
    sdk_dir = tmp_path / "cache" / "flutter"
    sdk_dir.mkdir(parents=True)

    bin_dir = sdk_dir / "bin"
    bin_dir.mkdir()
    flutter_bin = bin_dir / "flutter"
    flutter_bin.write_text("#!/bin/bash\necho flutter", encoding="utf-8")
    flutter_bin.chmod(0o755)

    dart_bin = bin_dir / "dart"
    dart_bin.write_text("#!/bin/bash\necho dart", encoding="utf-8")

    packages_dir = sdk_dir / "packages"
    packages_dir.mkdir()

    # Test finding the SDK
    exit_code = cli.main(
        ["find-flutter-sdk", "--search-root", str(tmp_path), "--max-depth", "5"]
    )

    assert exit_code == 0


def test_cli_find_flutter_sdk_not_found(tmp_path):
    """Test find-flutter-sdk when SDK is not found."""
    exit_code = cli.main(
        ["find-flutter-sdk", "--search-root", str(tmp_path), "--max-depth", "2"]
    )

    assert exit_code == 1  # Should fail when SDK not found


def test_cli_prepare_build_dir(tmp_path):
    """Test prepare-build-dir command."""
    build_dir = tmp_path / "build"
    pubspec_yaml = tmp_path / "pubspec.yaml"
    pubspec_lock = tmp_path / "pubspec.lock"

    pubspec_yaml.write_text("name: test\nversion: 1.0.0", encoding="utf-8")
    pubspec_lock.write_text("packages: {}", encoding="utf-8")

    exit_code = cli.main(
        [
            "prepare-build-dir",
            "--build-dir",
            str(build_dir),
            "--pubspec-yaml",
            str(pubspec_yaml),
            "--pubspec-lock",
            str(pubspec_lock),
        ]
    )

    assert exit_code == 0
    assert build_dir.exists()
    assert (build_dir / "pubspec.yaml").exists()
    assert (build_dir / "pubspec.lock").exists()
    assert (build_dir / "foreign_deps.json").exists()


def test_cli_prepare_build_dir_no_foreign_deps(tmp_path):
    """Test prepare-build-dir with --no-foreign-deps flag."""
    build_dir = tmp_path / "build"

    exit_code = cli.main(
        ["prepare-build-dir", "--build-dir", str(build_dir), "--no-foreign-deps"]
    )

    assert exit_code == 0
    assert build_dir.exists()
    assert not (build_dir / "foreign_deps.json").exists()


def test_cli_update_manifest_head_fallback(tmp_path, monkeypatch, capsys):
    """Test update-manifest uses HEAD when no commit specified."""
    import subprocess
    import shutil

    # Create manifest
    manifest_path = tmp_path / "manifest.yml"
    data = yaml.safe_load(SAMPLE_MANIFEST)
    manifest_path.write_text(yaml.safe_dump(data), encoding="utf-8")

    # Mock shutil.which to return a fake git path
    monkeypatch.setattr(
        shutil, "which", lambda cmd: "/usr/bin/git" if cmd == "git" else None
    )

    # Mock subprocess to return a fake HEAD commit
    def mock_check_output(cmd, **_kwargs):
        if "/usr/bin/git" in cmd[0] and "rev-parse" in cmd:
            return "fake-head-commit-sha\n"
        raise subprocess.CalledProcessError(1, cmd)

    monkeypatch.setattr(subprocess, "check_output", mock_check_output)

    # Run without --commit, should use HEAD
    exit_code = cli.main(["update-manifest", "--manifest", str(manifest_path)])

    assert exit_code == 0
    captured = capsys.readouterr()
    assert (
        "No commit specified, using current HEAD: fake-head-commit-sha" in captured.out
    )

    # Verify the manifest was updated with the HEAD commit
    updated_data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    lotti = next(m for m in updated_data["modules"] if m["name"] == "lotti")
    git_source = next(s for s in lotti["sources"] if s.get("type") == "git")
    assert git_source.get("commit") == "fake-head-commit-sha"
