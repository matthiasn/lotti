from __future__ import annotations

from pathlib import Path
import textwrap
import yaml

from manifest_tool import cli


def write_manifest(path: Path, text: str) -> None:
    path.write_text(textwrap.dedent(text), encoding="utf-8")


def load(path: Path) -> dict:
    return yaml.safe_load(path.read_text(encoding="utf-8"))


def test_end_to_end_postprocess_pipeline(tmp_path: Path) -> None:
    # Minimal manifest resembling the source layout with a rustup installer snippet
    manifest_path = tmp_path / "manifest.yml"
    write_manifest(
        manifest_path,
        """
        modules:
          - name: flutter-sdk
            build-commands:
              - mv flutter /app/flutter
              - export PATH=/app/flutter/bin:$PATH
            sources:
              - type: git
                url: https://github.com/flutter/flutter.git
                dest: flutter
          - name: lotti
            sources:
              - type: git
                url: https://github.com/matthiasn/lotti
                commit: COMMIT_PLACEHOLDER
            build-options:
              append-path: /usr/bin
              env:
                PATH: /usr/bin
            build-commands:
              - echo "Installing Rust..."
              - >
                curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
                sh -s -- -y --default-toolchain stable --profile minimal
              - export PATH=\"$HOME/.cargo/bin:$PATH\"
              - cp -r /app/flutter /run/build/lotti/flutter_sdk
              - echo build
        """,
    )

    # 1) Include rustup module before lotti (as string module include)
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

    # 2) Ensure rust env (PATH and RUSTUP_HOME), and drop rustup installer lines
    # Note: --share=network is NOT allowed in build-args on Flathub
    assert cli.main(["ensure-rust-sdk-env", "--manifest", str(manifest_path)]) == 0
    assert cli.main(["remove-rustup-install", "--manifest", str(manifest_path)]) == 0

    # 3) Attach offline source references and helper to lotti
    assert (
        cli.main(
            [
                "add-offline-sources",
                "--manifest",
                str(manifest_path),
                "--pubspec",
                "pubspec-sources.json",
                "--cargo",
                "cargo-sources.json",
                "--flutter-json",
                "flutter-sdk-3.35.7.json",
            ]
        )
        == 0
    )
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

    # 4) Normalize SDK copy (defensive)
    assert cli.main(["normalize-sdk-copy", "--manifest", str(manifest_path)]) == 0

    data = load(manifest_path)

    # Assert rustup module is included before lotti
    idx_mod = next(i for i, m in enumerate(data["modules"]) if m == "rustup-1.83.0.json")
    idx_lotti = next(i for i, m in enumerate(data["modules"]) if isinstance(m, dict) and m.get("name") == "lotti")
    assert idx_mod < idx_lotti

    lotti = data["modules"][idx_lotti]

    # Offline sources present and sanitized
    assert "pubspec-sources.json" in lotti["sources"]
    assert "cargo-sources.json" in lotti["sources"]
    assert any(isinstance(s, dict) and s.get("path") == "flutter-sdk-3.35.7.json" for s in lotti["sources"])
    # No rustup JSON under sources
    assert not any(
        (s == "rustup-1.83.0.json") or (isinstance(s, dict) and s.get("path") == "rustup-1.83.0.json")
        for s in lotti["sources"]
    )

    # Helper is added to flutter-sdk sources, not lotti
    flutter_sdk = next(m for m in data["modules"] if m["name"] == "flutter-sdk")
    assert any(isinstance(s, dict) and s.get("dest-filename") == "setup-flutter.sh" for s in flutter_sdk["sources"])
    # Command is added to lotti
    assert any("setup-flutter.sh" in c for c in lotti["build-commands"])

    # Build args and env updated (--share=network removed as it's not allowed on Flathub)
    assert "--share=network" not in lotti["build-options"].get("build-args", [])
    env = lotti["build-options"]["env"]
    assert env["PATH"].startswith("/usr/lib/sdk/rust-stable/bin")
    assert "/run/build/lotti/.cargo/bin" in env["PATH"]
    assert (
        "/usr/lib/sdk/rust-stable/bin" in lotti["build-options"]["append-path"]
        and "/run/build/lotti/.cargo/bin" in lotti["build-options"]["append-path"]
    )

    # rustup installer commands removed
    assert all("rustup.rs" not in c and "cargo/bin" not in c for c in lotti["build-commands"])


def test_end_to_end_nested_sdk_pipeline(tmp_path: Path) -> None:
    # Manifest with a top-level flutter-sdk and a lotti module
    manifest_path = tmp_path / "manifest.yml"
    write_manifest(
        manifest_path,
        """
        modules:
          - name: flutter-sdk
            build-commands:
              - mv flutter /app/flutter
              - export PATH=/app/flutter/bin:$PATH
            sources:
              - type: git
                url: https://github.com/flutter/flutter.git
                dest: flutter
          - name: lotti
            sources:
              - type: git
                url: https://github.com/matthiasn/lotti
                commit: COMMIT_PLACEHOLDER
            build-options:
              append-path: /usr/bin
              env:
                PATH: /usr/bin
            build-commands:
              - cp -r /app/flutter /run/build/lotti/flutter_sdk
              - echo build
        """,
    )

    # Prepare an output dir with an offline flutter JSON and artifacts
    out_dir = tmp_path / "out"
    out_dir.mkdir()
    (out_dir / "flutter-sdk-3.35.7.json").write_text("{}", encoding="utf-8")
    (out_dir / "pubspec-sources.json").write_text("{}", encoding="utf-8")
    (out_dir / "cargo-sources.json").write_text("{}", encoding="utf-8")
    (out_dir / "setup-flutter.sh").write_text("#!/bin/bash", encoding="utf-8")

    # Attach nested SDK json under lotti and bundle app archive (removes top-level flutter-sdk)
    assert (
        cli.main(
            [
                "ensure-nested-sdk",
                "--manifest",
                str(manifest_path),
                "--output-dir",
                str(out_dir),
            ]
        )
        == 0
    )
    assert (
        cli.main(
            [
                "bundle-app-archive",
                "--manifest",
                str(manifest_path),
                "--archive",
                "lotti.tar.xz",
                "--sha256",
                "cafebabe",
                "--output-dir",
                str(out_dir),
            ]
        )
        == 0
    )

    # Ensure nested layout: env PATH/append-path target /var/lib, helper present
    assert (
        cli.main(
            [
                "ensure-lotti-setup-helper",
                "--manifest",
                str(manifest_path),
                "--layout",
                "nested",
                "--helper",
                "setup-flutter.sh",
            ]
        )
        == 0
    )
    assert (
        cli.main(
            [
                "normalize-lotti-env",
                "--manifest",
                str(manifest_path),
                "--layout",
                "nested",
                "--append-path",
            ]
        )
        == 0
    )
    assert cli.main(["normalize-sdk-copy", "--manifest", str(manifest_path)]) == 0

    data = load(manifest_path)
    modules = data["modules"]
    # Top-level flutter-sdk removed
    assert not any(isinstance(m, dict) and m.get("name") == "flutter-sdk" for m in modules)
    lotti = next(m for m in modules if isinstance(m, dict) and m.get("name") == "lotti")
    # Nested modules include flutter JSON
    assert any(isinstance(n, str) and n.startswith("flutter-sdk-") for n in lotti.get("modules", []))
    # Env and helper adjusted for nested layout
    # When using --append-path flag, the path is added to append-path, not env.PATH
    assert lotti["build-options"]["append-path"].startswith("/var/lib/flutter/bin")
    assert any("setup-flutter.sh" in c and "-C /var/lib" in c for c in lotti["build-commands"])
