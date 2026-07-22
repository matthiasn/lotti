"""Tests for the R2 publish clock-skew workaround (pure logic; no network)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

TOOL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_ROOT))

from tutorial_videos.publish import _correct_clock_skew_from  # noqa: E402

try:
    import botocore.auth  # noqa: F401

    _HAS_BOTOCORE = True
except ImportError:
    _HAS_BOTOCORE = False


def _skewed_error(date_header: str | None) -> SimpleNamespace:
    headers = {"date": date_header} if date_header else {}
    return SimpleNamespace(response={"ResponseMetadata": {"HTTPHeaders": headers}})


@unittest.skipUnless(
    _HAS_BOTOCORE,
    "boto3/botocore is only installed in tools/tutorial_videos/.venv — run "
    "this file via `.venv/bin/python3 -m unittest tests.test_publish`",
)
class ClockSkewTest(unittest.TestCase):
    def test_returns_false_without_a_date_header(self):
        self.assertFalse(_correct_clock_skew_from(_skewed_error(None)))

    def test_patches_botocore_signing_clock_to_the_server_time(self):
        import datetime as dt

        import botocore.auth

        original = botocore.auth.get_current_datetime
        self.addCleanup(setattr, botocore.auth, "get_current_datetime", original)

        # A server date far from "now" — after correction, botocore's signing
        # clock must land within a few seconds of it, not of the real host
        # clock (which is exactly the drift this workaround exists to hide).
        future_date = (dt.datetime.now(dt.timezone.utc).replace(tzinfo=None) + dt.timedelta(hours=3)).strftime(
            "%a, %d %b %Y %H:%M:%S GMT"
        )
        self.assertTrue(_correct_clock_skew_from(_skewed_error(future_date)))

        corrected_now = botocore.auth.get_current_datetime()
        expected = dt.datetime.now(dt.timezone.utc).replace(tzinfo=None) + dt.timedelta(hours=3)
        self.assertLess(abs((corrected_now - expected).total_seconds()), 5)


if __name__ == "__main__":
    unittest.main()
