#!/usr/bin/env python3
"""Tests for Flatpak foreign-dependency validation."""

from __future__ import annotations

import unittest

from check_foreign_deps import LockedPackage, validate_native_fallbacks


class ValidateNativeFallbacksTest(unittest.TestCase):
    def test_rejects_package_root_patch_reused_for_newer_locked_version(self):
        bundled = {
            "sqlite3": {
                "2.9.4": {},
                "3.0.0": {
                    "manifest": {
                        "sources": [
                            {
                                "type": "patch",
                                "path": "sqlite3/assets.dart.patch",
                                "dest": "$PUB_DEV",
                            }
                        ]
                    }
                },
            }
        }
        locked = {"sqlite3": LockedPackage(source="hosted", version="3.5.1")}

        failures = validate_native_fallbacks(
            bundled_foreign_deps=bundled,
            overlay_foreign_deps={},
            locked_packages=locked,
        )

        self.assertEqual(
            failures,
            [
                "sqlite3 is locked at 3.5.1, but flatpak-flutter would reuse "
                "the native package-root entry for 3.0.0; add an exact "
                "foreign_deps overlay entry"
            ],
        )

    def test_accepts_exact_overlay_for_locked_version(self):
        bundled = {
            "sqlite3": {
                "3.0.0": {
                    "manifest": {
                        "sources": [
                            {
                                "type": "patch",
                                "path": "sqlite3/assets.dart.patch",
                                "dest": "$PUB_DEV",
                            }
                        ]
                    }
                }
            }
        }
        overlay = {"sqlite3": {"3.5.1": {"manifest": {"sources": []}}}}
        locked = {"sqlite3": LockedPackage(source="hosted", version="3.5.1")}

        self.assertEqual(
            validate_native_fallbacks(
                bundled_foreign_deps=bundled,
                overlay_foreign_deps=overlay,
                locked_packages=locked,
            ),
            [],
        )

    def test_allows_nested_tool_patch_to_follow_compatible_version(self):
        bundled = {
            "super_native_extensions": {
                "0.8.24": {
                    "manifest": {
                        "sources": [
                            {
                                "type": "patch",
                                "path": "cargokit/run_build_tool.sh.patch",
                                "dest": "$PUB_DEV/cargokit",
                            }
                        ]
                    }
                }
            }
        }
        locked = {
            "super_native_extensions": LockedPackage(
                source="hosted",
                version="0.9.1",
            )
        }

        self.assertEqual(
            validate_native_fallbacks(
                bundled_foreign_deps=bundled,
                overlay_foreign_deps={},
                locked_packages=locked,
            ),
            [],
        )


if __name__ == "__main__":
    unittest.main()
