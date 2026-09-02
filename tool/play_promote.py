"""Promote the Android build on Google Play's internal track to a store track.

Every release tag uploads the app bundle to Play's internal testing track
(``flutter-android-release.yml``). This is the second half: on a
``play/<track>/<version>`` tag, ``play-promote.yml`` runs this script, which
finds the release carrying that version's build number on the internal track
and promotes it - the same bytes, no rebuild - to closed testing (``alpha``),
open testing (``beta``) or ``production``, then commits the edit so Google
reviews it.

Promotion rather than a fresh build, because Play refuses a version code it
has already seen: the build number in ``pubspec.yaml`` moves once per
release, so by the time a build graduates it is already on internal.

The tag must name the version ``pubspec.yaml`` carries at the tagged commit.
That is the whole guard against promoting the wrong build: the version code
comes from the checkout, and the tag has to agree with it.

Only the Play Developer API client is imported lazily, in ``build_service``,
so the parsing and promotion logic runs against a fake service in tests.

    play_promote.py --tag play/alpha/1.0.25+4366
    play_promote.py --track production --dry-run
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

PACKAGE_NAME = "com.matthiasn.lotti"
SOURCE_TRACK = "internal"
TAG_PREFIX = "play/"
TRACKS = {
    "alpha": "closed testing",
    "beta": "open testing",
    "production": "production",
}
SCOPE = "https://www.googleapis.com/auth/androidpublisher"
CREDENTIALS_VAR = "PLAY_SERVICE_ACCOUNT_JSON"
_VERSION_PATTERN = re.compile(r"\d+\.\d+\.\d+\+(\d+)")


class PromotionError(RuntimeError):
    """Raised when the tag, the checkout or Play's state rules out the promotion."""


@dataclass(frozen=True)
class Target:
    """Where a build goes and which build: the track and the pubspec version."""

    track: str
    version: str

    @property
    def version_code(self) -> int:
        return parse_version(self.version)


@dataclass(frozen=True)
class Promotion:
    """What ``promote`` did: which build went where, and whether Play was told."""

    track: str
    version_code: int
    release_name: str | None
    committed: bool


def parse_version(version: str) -> int:
    """The build number of a ``<major>.<minor>.<patch>+<build>`` version.

    On Android the build number is the version code, the only identity Play
    knows a release by.
    """
    match = _VERSION_PATTERN.fullmatch(version)
    if match is None:
        raise PromotionError(
            f"version {version!r} must read <major>.<minor>.<patch>+<build>"
        )
    return int(match.group(1))


def parse_tag(tag: str) -> Target:
    """Reads ``play/<track>/<version>`` into a [Target].

    The track must be one Play promotes to; the version must carry a build
    number.
    """
    if not tag.startswith(TAG_PREFIX):
        raise PromotionError(f"tag {tag!r} is not under {TAG_PREFIX}")
    parts = tag[len(TAG_PREFIX) :].split("/")
    if len(parts) != 2:
        raise PromotionError(f"tag {tag!r} must read play/<track>/<version>")
    track, version = parts
    if track not in TRACKS:
        raise PromotionError(
            f"tag {tag!r} names the track {track!r}; "
            f"it must be one of {', '.join(TRACKS)}"
        )
    parse_version(version)
    return Target(track=track, version=version)


def read_pubspec_version(pubspec: Path) -> str:
    """The top-level ``version:`` value of a pubspec, quotes stripped."""
    for line in pubspec.read_text(encoding="utf-8").splitlines():
        if line.startswith("version:"):
            return line.split(":", 1)[1].strip().strip("\"'")
    raise PromotionError(f"no version: line in {pubspec}")


def resolve_target(
    *, tag: str | None, track: str | None, pubspec_version: str
) -> Target:
    """The [Target] of a run: from the tag on a tag push, else from ``track``.

    A tag that disagrees with the checkout's pubspec is refused, because the
    version code promoted comes from the checkout and the tag would then
    claim a different build than the one that moves.
    """
    if tag is not None:
        target = parse_tag(tag)
        if target.version != pubspec_version:
            raise PromotionError(
                f"tag {tag} names {target.version} but pubspec.yaml at this "
                f"commit says {pubspec_version}; tag the commit that carries "
                "the version you mean to promote"
            )
        return target
    if track is None:
        raise PromotionError("either a tag or a track is required")
    return Target(track=track, version=pubspec_version)


def release_for(track: Mapping[str, Any], version_code: int) -> dict[str, Any] | None:
    """The release on a ``tracks.get`` response that carries ``version_code``."""
    wanted = str(version_code)
    for release in track.get("releases", []):
        if wanted in release.get("versionCodes", []):
            return dict(release)
    return None


def unfinished_release(track: Mapping[str, Any]) -> dict[str, Any] | None:
    """The first release on a ``tracks.get`` response that is not completed.

    A draft, a halted release or a staged rollout still in progress. Play's
    reference says only that an update carries "desired changes", not what
    becomes of such a release, so the promotion refuses to write over one.
    """
    for release in track.get("releases", []):
        if release.get("status") != "completed":
            return dict(release)
    return None


def promote(
    service: Any,
    *,
    package_name: str,
    version_code: int,
    track: str,
    dry_run: bool = False,
) -> Promotion:
    """Moves the internal release with ``version_code`` onto ``track``.

    One Play edit: read the internal track, read the target track, write the
    target with that one version code as a completed release (keeping the
    release's name and notes), then commit it for review. A target track
    holding a draft, halted or in-progress release - a staged rollout someone
    started in the Play Console - is refused rather than written over. A dry
    run validates the edit server side and discards it instead of committing.
    An edit that is not committed is deleted on the way out so a failed run
    leaves nothing half-open.
    """
    edits = service.edits()
    edit_id = edits.insert(packageName=package_name, body={}).execute()["id"]
    committed = False
    try:
        tracks = edits.tracks()
        source = tracks.get(
            packageName=package_name, editId=edit_id, track=SOURCE_TRACK
        ).execute()
        release = release_for(source, version_code)
        if release is None:
            raise PromotionError(
                f"build {version_code} is not on the {SOURCE_TRACK} track yet; "
                "flutter-android-release.yml uploads it there on the release "
                "tag, so wait for that run to finish, then re-run this workflow "
                "from the Actions tab"
            )
        target = tracks.get(
            packageName=package_name, editId=edit_id, track=track
        ).execute()
        unfinished = unfinished_release(target)
        if unfinished is not None:
            codes = ", ".join(unfinished.get("versionCodes", [])) or "none"
            raise PromotionError(
                f"the {track} track holds a release in status "
                f"{unfinished.get('status', 'unknown')} (version codes {codes}); "
                "complete or remove it in the Play Console before promoting "
                "over it"
            )
        promoted: dict[str, Any] = {
            "versionCodes": [str(version_code)],
            "status": "completed",
        }
        for key in ("name", "releaseNotes"):
            if key in release:
                promoted[key] = release[key]
        tracks.update(
            packageName=package_name,
            editId=edit_id,
            track=track,
            body={"track": track, "releases": [promoted]},
        ).execute()
        if dry_run:
            edits.validate(packageName=package_name, editId=edit_id).execute()
        else:
            edits.commit(
                packageName=package_name,
                editId=edit_id,
                changesNotSentForReview=False,
            ).execute()
            committed = True
        return Promotion(
            track=track,
            version_code=version_code,
            release_name=release.get("name"),
            committed=committed,
        )
    finally:
        if not committed:
            try:
                edits.delete(packageName=package_name, editId=edit_id).execute()
            except Exception:  # noqa: BLE001 - best effort; edits expire anyway
                pass


def build_service(credentials_json: str) -> Any:
    """A Play Developer API client authenticated as the service account."""
    try:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build
    except ImportError as error:
        raise PromotionError(
            "Promoting requires the Play API client: "
            "pip install google-api-python-client google-auth"
        ) from error
    credentials = service_account.Credentials.from_service_account_info(
        json.loads(credentials_json), scopes=[SCOPE]
    )
    return build(
        "androidpublisher", "v3", credentials=credentials, cache_discovery=False
    )


def describe(promotion: Promotion, target: Target) -> str:
    """One line for the log and the job summary."""
    outcome = (
        "sent it for review"
        if promotion.committed
        else "dry run, validated and discarded"
    )
    return (
        f"Promoted build {promotion.version_code} ({target.version}) from "
        f"{SOURCE_TRACK} to {TRACKS[target.track]} ({target.track}); {outcome}"
    )


def _parse_args(argv: Sequence[str] | None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    where = parser.add_mutually_exclusive_group(required=True)
    where.add_argument(
        "--tag", help="the play/<track>/<version> tag this run was pushed by"
    )
    where.add_argument(
        "--track",
        choices=sorted(TRACKS),
        help="the track to promote to, for a run without a tag",
    )
    parser.add_argument(
        "--pubspec",
        type=Path,
        default=Path("pubspec.yaml"),
        help="the pubspec whose version names the build (default: pubspec.yaml)",
    )
    parser.add_argument(
        "--package",
        default=PACKAGE_NAME,
        help=f"the application id on Play (default: {PACKAGE_NAME})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="validate the edit with Play and discard it instead of committing",
    )
    return parser.parse_args(argv)


def main(
    argv: Sequence[str] | None = None,
    *,
    env: Mapping[str, str] | None = None,
    service_factory: Callable[[str], Any] = build_service,
) -> int:
    """Entry point: resolves the target, promotes, reports. Returns the exit code."""
    environment = os.environ if env is None else env
    args = _parse_args(argv)
    try:
        target = resolve_target(
            tag=args.tag,
            track=args.track,
            pubspec_version=read_pubspec_version(args.pubspec),
        )
        credentials = environment.get(CREDENTIALS_VAR, "")
        if not credentials:
            raise PromotionError(f"{CREDENTIALS_VAR} is not set")
        promotion = promote(
            service_factory(credentials),
            package_name=args.package,
            version_code=target.version_code,
            track=target.track,
            dry_run=args.dry_run,
        )
    except PromotionError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    line = describe(promotion, target)
    print(line)
    summary_path = environment.get("GITHUB_STEP_SUMMARY")
    if summary_path:
        with Path(summary_path).open("a", encoding="utf-8") as summary:
            summary.write(f"### {line}\n")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
