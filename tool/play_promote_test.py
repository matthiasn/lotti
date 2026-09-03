from __future__ import annotations

import io
import os
import sys
import tempfile
import types
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

from play_promote import (
    CREDENTIALS_VAR,
    SCOPE,
    SOURCE_TRACK,
    Promotion,
    PromotionError,
    Target,
    build_service,
    bundle_uploaded,
    describe,
    main,
    parse_tag,
    parse_version,
    promote,
    read_pubspec_version,
    release_for,
    resolve_target,
    unfinished_release,
)

_INTERNAL_RELEASE = {
    "name": "1.0.25+4366",
    "versionCodes": ["4366"],
    "status": "completed",
    "releaseNotes": [{"language": "en-US", "text": "Fixes."}],
}
_INTERNAL_TRACK = {"track": "internal", "releases": [_INTERNAL_RELEASE]}
_ROLLOUT_IN_PROGRESS = {
    "track": "production",
    "releases": [
        {"versionCodes": ["4360"], "status": "inProgress", "userFraction": 0.1}
    ],
}


class _Request:
    """One deferred API call, the way the Google client returns them."""

    def __init__(self, result=None, error: Exception | None = None):
        self.result = result
        self.error = error

    def execute(self):
        if self.error is not None:
            raise self.error
        return self.result


class _FakeTracks:
    """Stands in for ``service.edits().tracks()``.

    Answers ``get`` from a map of track name to response - a track absent
    from the map reads as empty, the way Play answers for a track nothing was
    ever released to - and records into the edits' shared call list under
    ``tracks.<method>`` so a call on the wrong collection cannot pass.
    """

    def __init__(
        self,
        calls: list[tuple[str, dict]],
        tracks: dict[str, dict],
        update_error: Exception | None,
    ):
        self._calls = calls
        self._tracks = tracks
        self._update_error = update_error

    def get(self, **kwargs):
        self._calls.append(("tracks.get", kwargs))
        name = kwargs["track"]
        return _Request(self._tracks.get(name, {"track": name}))

    def update(self, **kwargs):
        self._calls.append(("tracks.update", kwargs))
        return _Request(kwargs["body"], self._update_error)


class _FakeBundles:
    """Stands in for ``service.edits().bundles()``: every uploaded bundle."""

    def __init__(self, calls: list[tuple[str, dict]], version_codes: list[int]):
        self._calls = calls
        self._version_codes = version_codes

    def list(self, **kwargs):
        self._calls.append(("bundles.list", kwargs))
        return _Request(
            {"bundles": [{"versionCode": code} for code in self._version_codes]}
        )


class _FakeEdits:
    """Stands in for ``service.edits()``.

    Records every call as ``(method, kwargs)`` so a test can assert the exact
    sequence and bodies that reached Play.
    """

    def __init__(
        self,
        tracks: dict[str, dict] | None = None,
        *,
        bundles: list[int] | None = None,
        update_error: Exception | None = None,
        delete_error: Exception | None = None,
    ):
        self.tracks_by_name = (
            {"internal": _INTERNAL_TRACK} if tracks is None else tracks
        )
        self.uploaded = [4366] if bundles is None else bundles
        self.update_error = update_error
        self.delete_error = delete_error
        self.calls: list[tuple[str, dict]] = []

    def _record(self, method: str, kwargs: dict):
        self.calls.append((method, kwargs))

    def methods(self) -> list[str]:
        return [method for method, _ in self.calls]

    def calls_of(self, method: str) -> list[dict]:
        return [kwargs for name, kwargs in self.calls if name == method]

    def kwargs_of(self, method: str) -> dict:
        return self.calls_of(method)[0]

    def insert(self, **kwargs):
        self._record("insert", kwargs)
        return _Request({"id": "edit-1"})

    def tracks(self):
        return _FakeTracks(self.calls, self.tracks_by_name, self.update_error)

    def bundles(self):
        return _FakeBundles(self.calls, self.uploaded)

    def validate(self, **kwargs):
        self._record("validate", kwargs)
        return _Request({"id": "edit-1"})

    def commit(self, **kwargs):
        self._record("commit", kwargs)
        return _Request({"id": "edit-1"})

    def delete(self, **kwargs):
        self._record("delete", kwargs)
        return _Request(None, self.delete_error)


class _FakeService:
    def __init__(self, edits: _FakeEdits):
        self._edits = edits

    def edits(self):
        return self._edits


class ParseVersionTest(unittest.TestCase):
    def test_returns_the_build_number(self):
        self.assertEqual(parse_version("1.0.25+4366"), 4366)

    def test_rejects_a_version_without_a_build_number(self):
        with self.assertRaisesRegex(PromotionError, "must read"):
            parse_version("1.0.25")

    def test_rejects_a_non_numeric_build_number(self):
        with self.assertRaisesRegex(PromotionError, "must read"):
            parse_version("1.0.25+beta")

    def test_rejects_trailing_text(self):
        with self.assertRaisesRegex(PromotionError, "must read"):
            parse_version("1.0.25+4366-rc1")


class ParseTagTest(unittest.TestCase):
    def test_reads_a_closed_testing_tag(self):
        self.assertEqual(
            parse_tag("play/alpha/1.0.25+4366"),
            Target(track="alpha", version="1.0.25+4366"),
        )

    def test_reads_an_open_testing_tag(self):
        self.assertEqual(parse_tag("play/beta/1.0.25+4366").track, "beta")

    def test_reads_a_production_tag(self):
        self.assertEqual(parse_tag("play/production/1.0.25+4366").track, "production")

    def test_target_exposes_the_version_code(self):
        self.assertEqual(parse_tag("play/alpha/1.0.25+4366").version_code, 4366)

    def test_rejects_a_release_tag(self):
        with self.assertRaisesRegex(PromotionError, "not under play/"):
            parse_tag("1.0.25+4366")

    def test_rejects_an_unknown_track(self):
        with self.assertRaisesRegex(PromotionError, "alpha, beta, production"):
            parse_tag("play/internal/1.0.25+4366")

    def test_rejects_a_missing_version_segment(self):
        with self.assertRaisesRegex(PromotionError, "play/<track>/<version>"):
            parse_tag("play/alpha")

    def test_rejects_an_extra_segment(self):
        with self.assertRaisesRegex(PromotionError, "play/<track>/<version>"):
            parse_tag("play/alpha/1.0.25+4366/again")

    def test_rejects_a_malformed_version(self):
        with self.assertRaisesRegex(PromotionError, "must read"):
            parse_tag("play/alpha/1.0.25")


class ReadPubspecVersionTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.pubspec = Path(self.temp_dir.name) / "pubspec.yaml"

    def test_reads_the_top_level_version(self):
        self.pubspec.write_text("name: lotti\nversion: 1.0.25+4366\n")
        self.assertEqual(read_pubspec_version(self.pubspec), "1.0.25+4366")

    def test_strips_quotes(self):
        self.pubspec.write_text('version: "1.0.25+4366"\n')
        self.assertEqual(read_pubspec_version(self.pubspec), "1.0.25+4366")

    def test_ignores_indented_version_keys(self):
        self.pubspec.write_text(
            "dependencies:\n  foo:\n    version: 9.9.9\nversion: 1.0.25+4366\n"
        )
        self.assertEqual(read_pubspec_version(self.pubspec), "1.0.25+4366")

    def test_rejects_a_pubspec_without_a_version(self):
        self.pubspec.write_text("name: lotti\n")
        with self.assertRaisesRegex(PromotionError, "no version: line"):
            read_pubspec_version(self.pubspec)


class ResolveTargetTest(unittest.TestCase):
    def test_a_tag_that_matches_the_pubspec_wins(self):
        target = resolve_target(
            tag="play/beta/1.0.25+4366", track=None, pubspec_version="1.0.25+4366"
        )
        self.assertEqual(target, Target(track="beta", version="1.0.25+4366"))

    def test_a_tag_that_disagrees_with_the_pubspec_is_refused(self):
        with self.assertRaisesRegex(PromotionError, "pubspec.yaml at this commit"):
            resolve_target(
                tag="play/beta/1.0.25+4366",
                track=None,
                pubspec_version="1.0.26+4367",
            )

    def test_a_track_alone_takes_the_pubspec_version(self):
        target = resolve_target(
            tag=None, track="production", pubspec_version="1.0.25+4366"
        )
        self.assertEqual(target, Target(track="production", version="1.0.25+4366"))

    def test_neither_tag_nor_track_is_refused(self):
        with self.assertRaisesRegex(PromotionError, "tag or a track"):
            resolve_target(tag=None, track=None, pubspec_version="1.0.25+4366")


class ReleaseForTest(unittest.TestCase):
    def test_finds_the_release_carrying_the_version_code(self):
        self.assertEqual(release_for(_INTERNAL_TRACK, 4366), _INTERNAL_RELEASE)

    def test_returns_a_copy(self):
        found = release_for(_INTERNAL_TRACK, 4366)
        assert found is not None
        found["status"] = "halted"
        self.assertEqual(_INTERNAL_RELEASE["status"], "completed")

    def test_picks_among_several_releases(self):
        track = {
            "releases": [
                {"versionCodes": ["4360"], "status": "completed"},
                {"versionCodes": ["4365", "4366"], "status": "inProgress"},
            ]
        }
        self.assertEqual(release_for(track, 4366), track["releases"][1])

    def test_none_when_the_version_code_is_absent(self):
        self.assertIsNone(release_for(_INTERNAL_TRACK, 4367))

    def test_none_when_the_track_has_no_releases(self):
        self.assertIsNone(release_for({"track": "internal"}, 4366))


class BundleUploadedTest(unittest.TestCase):
    def test_true_when_a_bundle_carries_the_version_code(self):
        bundles = {"bundles": [{"versionCode": 4360}, {"versionCode": 4366}]}
        self.assertTrue(bundle_uploaded(bundles, 4366))

    def test_accepts_a_version_code_serialised_as_text(self):
        self.assertTrue(bundle_uploaded({"bundles": [{"versionCode": "4366"}]}, 4366))

    def test_false_when_no_bundle_carries_it(self):
        self.assertFalse(bundle_uploaded({"bundles": [{"versionCode": 4360}]}, 4366))

    def test_false_for_an_app_with_no_bundles(self):
        self.assertFalse(bundle_uploaded({}, 4366))

    def test_a_bundle_without_a_version_code_never_matches(self):
        self.assertFalse(bundle_uploaded({"bundles": [{}]}, 4366))


class UnfinishedReleaseTest(unittest.TestCase):
    def test_none_when_every_release_is_completed(self):
        self.assertIsNone(unfinished_release(_INTERNAL_TRACK))

    def test_none_when_the_track_has_no_releases(self):
        self.assertIsNone(unfinished_release({"track": "production"}))

    def test_finds_a_staged_rollout(self):
        self.assertEqual(
            unfinished_release(_ROLLOUT_IN_PROGRESS),
            _ROLLOUT_IN_PROGRESS["releases"][0],
        )

    def test_finds_a_draft_behind_a_completed_release(self):
        track = {
            "releases": [
                {"versionCodes": ["4360"], "status": "completed"},
                {"versionCodes": ["4361"], "status": "draft"},
            ]
        }
        self.assertEqual(unfinished_release(track), track["releases"][1])

    def test_a_release_without_a_status_counts_as_unfinished(self):
        track = {"releases": [{"versionCodes": ["4360"]}]}
        self.assertEqual(unfinished_release(track), track["releases"][0])

    def test_returns_a_copy(self):
        found = unfinished_release(_ROLLOUT_IN_PROGRESS)
        assert found is not None
        found["status"] = "completed"
        self.assertEqual(_ROLLOUT_IN_PROGRESS["releases"][0]["status"], "inProgress")


class PromoteTest(unittest.TestCase):
    def _promote(
        self,
        edits: _FakeEdits,
        *,
        version_code: int = 4366,
        track: str = "alpha",
        dry_run: bool = False,
    ) -> Promotion:
        return promote(
            _FakeService(edits),
            package_name="com.example.app",
            version_code=version_code,
            track=track,
            dry_run=dry_run,
        )

    def test_reads_internal_then_the_target_then_writes_it_in_one_edit(self):
        edits = _FakeEdits()
        self._promote(edits)
        self.assertEqual(
            edits.methods(),
            ["insert", "tracks.get", "tracks.get", "tracks.update", "commit"],
        )
        reads = edits.calls_of("tracks.get")
        self.assertEqual(reads[0]["track"], SOURCE_TRACK)
        self.assertEqual(reads[1]["track"], "alpha")
        update = edits.kwargs_of("tracks.update")
        self.assertEqual(update["track"], "alpha")
        self.assertEqual(update["editId"], "edit-1")
        self.assertEqual(update["packageName"], "com.example.app")

    def test_promotes_exactly_one_completed_release(self):
        edits = _FakeEdits()
        self._promote(edits, track="production")
        body = edits.kwargs_of("tracks.update")["body"]
        self.assertEqual(body["track"], "production")
        self.assertEqual(len(body["releases"]), 1)
        self.assertEqual(body["releases"][0]["versionCodes"], ["4366"])
        self.assertEqual(body["releases"][0]["status"], "completed")

    def test_carries_the_release_name_and_notes_across(self):
        edits = _FakeEdits()
        self._promote(edits)
        release = edits.kwargs_of("tracks.update")["body"]["releases"][0]
        self.assertEqual(release["name"], "1.0.25+4366")
        self.assertEqual(release["releaseNotes"], _INTERNAL_RELEASE["releaseNotes"])

    def test_omits_name_and_notes_the_internal_release_lacks(self):
        edits = _FakeEdits({"internal": {"releases": [{"versionCodes": ["4366"]}]}})
        promotion = self._promote(edits)
        release = edits.kwargs_of("tracks.update")["body"]["releases"][0]
        self.assertNotIn("name", release)
        self.assertNotIn("releaseNotes", release)
        self.assertIsNone(promotion.release_name)

    def test_commits_for_review_and_reports_it(self):
        edits = _FakeEdits()
        promotion = self._promote(edits)
        self.assertIs(edits.kwargs_of("commit")["changesNotSentForReview"], False)
        self.assertEqual(
            promotion,
            Promotion(
                track="alpha",
                version_code=4366,
                release_name="1.0.25+4366",
                committed=True,
            ),
        )

    def test_a_committed_edit_is_not_deleted(self):
        edits = _FakeEdits()
        self._promote(edits)
        self.assertNotIn("delete", edits.methods())

    def test_writes_over_a_completed_release_on_the_target(self):
        edits = _FakeEdits(
            {
                "internal": _INTERNAL_TRACK,
                "production": {
                    "releases": [{"versionCodes": ["4360"], "status": "completed"}]
                },
            }
        )
        self._promote(edits, track="production")
        self.assertIn("commit", edits.methods())

    def test_refuses_to_write_over_a_staged_rollout_and_drops_the_edit(self):
        edits = _FakeEdits(
            {"internal": _INTERNAL_TRACK, "production": _ROLLOUT_IN_PROGRESS}
        )
        with self.assertRaisesRegex(
            PromotionError,
            "production track holds a release in status inProgress "
            r"\(version codes 4360\)",
        ):
            self._promote(edits, track="production")
        self.assertEqual(
            edits.methods(), ["insert", "tracks.get", "tracks.get", "delete"]
        )

    def test_names_an_unfinished_release_without_status_or_codes(self):
        edits = _FakeEdits({"internal": _INTERNAL_TRACK, "alpha": {"releases": [{}]}})
        with self.assertRaisesRegex(
            PromotionError, r"status unknown \(version codes none\)"
        ):
            self._promote(edits)

    def test_dry_run_validates_and_discards_instead_of_committing(self):
        edits = _FakeEdits()
        promotion = self._promote(edits, dry_run=True)
        self.assertEqual(
            edits.methods(),
            [
                "insert",
                "tracks.get",
                "tracks.get",
                "tracks.update",
                "validate",
                "delete",
            ],
        )
        self.assertEqual(edits.kwargs_of("delete")["editId"], "edit-1")
        self.assertFalse(promotion.committed)

    def test_a_build_superseded_on_internal_is_promoted_from_the_bundle_list(self):
        edits = _FakeEdits(
            {"internal": {"releases": [{"versionCodes": ["4367"]}]}},
            bundles=[4366, 4367],
        )
        promotion = self._promote(edits, version_code=4366)
        self.assertEqual(
            edits.methods(),
            [
                "insert",
                "tracks.get",
                "bundles.list",
                "tracks.get",
                "tracks.update",
                "commit",
            ],
        )
        release = edits.kwargs_of("tracks.update")["body"]["releases"][0]
        self.assertEqual(release, {"versionCodes": ["4366"], "status": "completed"})
        self.assertIsNone(promotion.release_name)

    def test_a_build_play_never_received_is_refused_and_the_edit_dropped(self):
        edits = _FakeEdits(bundles=[4366])
        with self.assertRaisesRegex(
            PromotionError,
            "4367 has not been uploaded to Play; flutter-android-release.yml",
        ):
            self._promote(edits, version_code=4367)
        self.assertEqual(
            edits.methods(), ["insert", "tracks.get", "bundles.list", "delete"]
        )

    def test_the_bundle_list_is_not_consulted_while_internal_still_holds_the_build(
        self,
    ):
        edits = _FakeEdits(bundles=[])
        self._promote(edits)
        self.assertNotIn("bundles.list", edits.methods())

    def test_an_api_failure_drops_the_edit_and_propagates(self):
        edits = _FakeEdits(update_error=RuntimeError("403 forbidden"))
        with self.assertRaisesRegex(RuntimeError, "403 forbidden"):
            self._promote(edits)
        self.assertEqual(
            edits.methods(),
            ["insert", "tracks.get", "tracks.get", "tracks.update", "delete"],
        )

    def test_a_failing_delete_does_not_mask_the_outcome(self):
        edits = _FakeEdits(delete_error=RuntimeError("gone"))
        promotion = self._promote(edits, dry_run=True)
        self.assertFalse(promotion.committed)
        self.assertEqual(edits.methods()[-1], "delete")


class BuildServiceTest(unittest.TestCase):
    def _fake_client_modules(self):
        recorded: dict[str, object] = {}

        class _Credentials:
            @staticmethod
            def from_service_account_info(info, scopes):
                recorded["info"] = info
                recorded["scopes"] = scopes
                return "credentials"

        def build(api, version, **kwargs):
            recorded["build"] = (api, version, kwargs)
            return "service"

        google = types.ModuleType("google")
        oauth2 = types.ModuleType("google.oauth2")
        service_account = types.ModuleType("google.oauth2.service_account")
        service_account.Credentials = _Credentials  # type: ignore[attr-defined]
        oauth2.service_account = service_account  # type: ignore[attr-defined]
        google.oauth2 = oauth2  # type: ignore[attr-defined]
        googleapiclient = types.ModuleType("googleapiclient")
        discovery = types.ModuleType("googleapiclient.discovery")
        discovery.build = build  # type: ignore[attr-defined]
        googleapiclient.discovery = discovery  # type: ignore[attr-defined]
        modules = {
            "google": google,
            "google.oauth2": oauth2,
            "google.oauth2.service_account": service_account,
            "googleapiclient": googleapiclient,
            "googleapiclient.discovery": discovery,
        }
        return modules, recorded

    def test_authenticates_the_service_account_for_the_publisher_scope(self):
        modules, recorded = self._fake_client_modules()
        with mock.patch.dict(sys.modules, modules):
            service = build_service('{"type": "service_account"}')
        self.assertEqual(service, "service")
        self.assertEqual(recorded["info"], {"type": "service_account"})
        self.assertEqual(recorded["scopes"], [SCOPE])
        self.assertEqual(
            recorded["build"],
            (
                "androidpublisher",
                "v3",
                {"credentials": "credentials", "cache_discovery": False},
            ),
        )

    def test_names_the_packages_to_install_when_the_client_is_missing(self):
        absent = {
            "google": None,
            "google.oauth2": None,
            "google.oauth2.service_account": None,
            "googleapiclient": None,
            "googleapiclient.discovery": None,
        }
        with mock.patch.dict(sys.modules, absent):
            with self.assertRaisesRegex(PromotionError, "google-api-python-client"):
                build_service("{}")


class DescribeTest(unittest.TestCase):
    def test_names_build_version_tracks_and_the_review(self):
        line = describe(
            Promotion(
                track="alpha",
                version_code=4366,
                release_name=None,
                committed=True,
            ),
            Target(track="alpha", version="1.0.25+4366"),
        )
        self.assertEqual(
            line,
            "Promoted build 4366 (1.0.25+4366) from internal to closed testing "
            "(alpha); sent it for review",
        )

    def test_says_when_nothing_was_committed(self):
        line = describe(
            Promotion(
                track="production",
                version_code=4366,
                release_name=None,
                committed=False,
            ),
            Target(track="production", version="1.0.25+4366"),
        )
        self.assertTrue(line.endswith("(production); dry run, validated and discarded"))


class MainTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.root = Path(self.temp_dir.name)
        self.pubspec = self.root / "pubspec.yaml"
        self.pubspec.write_text("version: 1.0.25+4366\n")
        self.edits = _FakeEdits()
        self.factory_calls: list[str] = []

    def _factory(self, credentials: str):
        self.factory_calls.append(credentials)
        return _FakeService(self.edits)

    def _run(self, *argv: str, env: dict[str, str] | None = None):
        out, err = io.StringIO(), io.StringIO()
        environment = {CREDENTIALS_VAR: "{}"} if env is None else env
        with redirect_stdout(out), redirect_stderr(err):
            code = main(
                ["--pubspec", str(self.pubspec), *argv],
                env=environment,
                service_factory=self._factory,
            )
        return code, out.getvalue(), err.getvalue()

    def test_a_tag_push_promotes_the_pubspec_build_to_the_tagged_track(self):
        code, out, err = self._run("--tag", "play/alpha/1.0.25+4366")
        self.assertEqual((code, err), (0, ""))
        self.assertIn("build 4366 (1.0.25+4366) from internal to closed testing", out)
        self.assertEqual(self.edits.kwargs_of("tracks.update")["track"], "alpha")
        self.assertEqual(
            self.edits.kwargs_of("tracks.update")["packageName"],
            "com.matthiasn.lotti",
        )

    def test_a_dispatch_run_takes_the_track_from_the_flag(self):
        code, out, _ = self._run(
            "--track", "production", "--package", "com.example.app"
        )
        self.assertEqual(code, 0)
        self.assertIn("to production (production)", out)
        self.assertEqual(
            self.edits.kwargs_of("tracks.update")["packageName"], "com.example.app"
        )

    def test_hands_the_credentials_to_the_service_factory(self):
        self._run("--track", "beta", env={CREDENTIALS_VAR: '{"k": 1}'})
        self.assertEqual(self.factory_calls, ['{"k": 1}'])

    def test_dry_run_reaches_the_promotion(self):
        code, out, _ = self._run("--track", "beta", "--dry-run")
        self.assertEqual(code, 0)
        self.assertIn("validate", self.edits.methods())
        self.assertIn("dry run", out)

    def test_a_mismatched_tag_fails_before_touching_play(self):
        code, _, err = self._run("--tag", "play/alpha/1.0.26+4367")
        self.assertEqual(code, 1)
        self.assertIn("error: tag play/alpha/1.0.26+4367 names 1.0.26+4367", err)
        self.assertEqual(self.factory_calls, [])

    def test_missing_credentials_fail_before_touching_play(self):
        code, _, err = self._run("--track", "alpha", env={})
        self.assertEqual(code, 1)
        self.assertIn(f"error: {CREDENTIALS_VAR} is not set", err)
        self.assertEqual(self.factory_calls, [])

    def test_a_refused_promotion_is_reported_as_an_error(self):
        self.edits = _FakeEdits({"internal": {"releases": []}}, bundles=[])
        code, _, err = self._run("--track", "alpha")
        self.assertEqual(code, 1)
        self.assertIn("error: build 4366 has not been uploaded to Play", err)

    def test_appends_the_outcome_to_the_step_summary(self):
        summary = self.root / "summary.md"
        summary.write_text("earlier\n")
        code, out, _ = self._run(
            "--track",
            "alpha",
            env={CREDENTIALS_VAR: "{}", "GITHUB_STEP_SUMMARY": str(summary)},
        )
        self.assertEqual(code, 0)
        self.assertEqual(summary.read_text(), f"earlier\n### {out.strip()}\n")

    def test_writes_no_summary_file_without_the_variable(self):
        self._run("--track", "alpha")
        self.assertEqual(sorted(p.name for p in self.root.iterdir()), ["pubspec.yaml"])

    def test_tag_and_track_together_are_rejected_by_the_parser(self):
        with redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                self._run("--tag", "play/alpha/1.0.25+4366", "--track", "alpha")

    def test_an_unknown_track_flag_is_rejected_by_the_parser(self):
        with redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit):
                self._run("--track", "internal")

    def test_reads_credentials_from_the_process_environment_by_default(self):
        # GitHub Actions sets GITHUB_STEP_SUMMARY in every step; left in place,
        # this run would append a line to the real summary of the CI job.
        environment = {
            name: value
            for name, value in os.environ.items()
            if name != "GITHUB_STEP_SUMMARY"
        }
        environment[CREDENTIALS_VAR] = "from-env"
        with mock.patch.dict("os.environ", environment, clear=True):
            with redirect_stdout(io.StringIO()):
                code = main(
                    ["--pubspec", str(self.pubspec), "--track", "alpha"],
                    service_factory=self._factory,
                )
        self.assertEqual(code, 0)
        self.assertEqual(self.factory_calls, ["from-env"])


if __name__ == "__main__":
    unittest.main()
