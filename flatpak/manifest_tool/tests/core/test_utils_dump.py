from __future__ import annotations

from pathlib import Path

from manifest_tool.core import utils


def test_dump_manifest_literal_block_for_multiline(tmp_path: Path) -> None:
    data = {
        "modules": [
            {
                "name": "lotti",
                "build-commands": [
                    "cp -r /var/lib/flutter /run/build/lotti/flutter_sdk",
                    (
                        'arch="x64"\n'
                        'if [ "${FLATPAK_ARCH}" = "aarch64" ]; then\n'
                        '  arch="arm64"\n'
                        "fi\n"
                        "cp -r build/linux/${arch}/release/bundle/* /app/"
                    ),
                ],
            }
        ]
    }
    out = tmp_path / "manifest.yml"
    utils.dump_manifest(out, data)

    text = out.read_text(encoding="utf-8")

    assert "|-" in text or "|" in text  # literal block style used
    assert 'arch="x64"' in text
    assert "cp -r build/linux/${arch}/release/bundle/* /app/" in text
    # Ensure single-line string remains plain (first command)
    assert "cp -r /var/lib/flutter /run/build/lotti/flutter_sdk" in text
