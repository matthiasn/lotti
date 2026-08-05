"""Publish immutable pull-request screenshots to Cloudflare R2.

The source directory contains ``before/`` and ``after/`` PNGs. Objects are
stored below ``pr-screenshots/<topic>/<commit>/`` and are never overwritten.
Re-running an upload is idempotent only when the existing object's recorded
SHA-256 matches the local file.
"""

from __future__ import annotations

import argparse
import hashlib
import re
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

CACHE_CONTROL = "public,max-age=31536000,immutable"
ENV_VARS = (
    "R2_ACCOUNT_ID",
    "R2_ACCESS_KEY_ID",
    "R2_SECRET_ACCESS_KEY",
    "R2_BUCKET_NAME",
    "R2_PUBLIC_BASE_URL",
)
_TOPIC_PATTERN = re.compile(r"[a-z0-9](?:[a-z0-9._-]*[a-z0-9])?")
_COMMIT_PATTERN = re.compile(r"[0-9a-f]{40}")


class PublishError(RuntimeError):
    """Raised when an upload would violate the immutable-object contract."""


@dataclass(frozen=True)
class ScreenshotUpload:
    path: Path
    key: str
    sha256: str


def _read_env(env_path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw_line in env_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.removeprefix("export ").strip()
        if key in ENV_VARS:
            values[key] = value.strip().strip("'\"")
    missing = [key for key in ENV_VARS if not values.get(key)]
    if missing:
        raise PublishError(f"Missing R2 configuration: {', '.join(missing)}")
    return values


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def discover_uploads(
    source: Path,
    *,
    topic: str,
    commit: str,
) -> list[ScreenshotUpload]:
    if not _TOPIC_PATTERN.fullmatch(topic):
        raise PublishError(
            "Topic must use lowercase letters, numbers, dots, dashes, or underscores"
        )
    if not _COMMIT_PATTERN.fullmatch(commit):
        raise PublishError("Commit must be a full lowercase 40-character SHA")
    if not source.is_dir():
        raise PublishError(f"Screenshot source does not exist: {source}")

    paths = sorted(
        path
        for state in ("before", "after")
        for path in (source / state).glob("**/*.png")
        if path.is_file()
    )
    if not paths:
        raise PublishError("No before/ or after/ PNG screenshots found")

    prefix = f"pr-screenshots/{topic}/{commit}"
    return [
        ScreenshotUpload(
            path=path,
            key=f"{prefix}/{path.relative_to(source).as_posix()}",
            sha256=_sha256(path),
        )
        for path in paths
    ]


def _default_client_factory(values: dict[str, str]):
    try:
        import boto3
    except ImportError as error:
        raise PublishError("Publishing requires boto3: pip install boto3") from error
    return boto3.client(
        "s3",
        endpoint_url=(
            f"https://{values['R2_ACCOUNT_ID']}.r2.cloudflarestorage.com"
        ),
        aws_access_key_id=values["R2_ACCESS_KEY_ID"],
        aws_secret_access_key=values["R2_SECRET_ACCESS_KEY"],
        region_name="auto",
    )


def _existing_sha256(client: Any, *, bucket: str, key: str) -> str | None:
    try:
        response = client.head_object(Bucket=bucket, Key=key)
    except Exception as error:  # boto3 is an optional, lazily loaded dependency.
        code = str(getattr(error, "response", {}).get("Error", {}).get("Code", ""))
        if code in {"404", "NoSuchKey", "NotFound"}:
            return None
        raise PublishError(f"R2 lookup failed for {key}: {error}") from error
    return response.get("Metadata", {}).get("sha256") or "unknown"


def publish_screenshots(
    source: Path,
    *,
    topic: str,
    commit: str,
    env_path: Path,
    client_factory: Callable[[dict[str, str]], Any] = _default_client_factory,
) -> list[str]:
    values = _read_env(env_path)
    uploads = discover_uploads(source, topic=topic, commit=commit)
    client = client_factory(values)
    bucket = values["R2_BUCKET_NAME"]

    pending: list[ScreenshotUpload] = []
    for upload in uploads:
        existing_sha256 = _existing_sha256(client, bucket=bucket, key=upload.key)
        if existing_sha256 is None:
            pending.append(upload)
        elif existing_sha256 != upload.sha256:
            raise PublishError(
                f"Refusing to overwrite immutable object {upload.key}; "
                "use a new filename or commit prefix"
            )

    for upload in pending:
        with upload.path.open("rb") as stream:
            client.put_object(
                Bucket=bucket,
                Key=upload.key,
                Body=stream,
                ContentType="image/png",
                CacheControl=CACHE_CONTROL,
                Metadata={"sha256": upload.sha256},
            )

    public_base = values["R2_PUBLIC_BASE_URL"].rstrip("/")
    return [f"{public_base}/{upload.key}" for upload in uploads]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--topic", required=True)
    parser.add_argument("--commit", required=True)
    parser.add_argument("--env-file", type=Path, default=Path(".env"))
    args = parser.parse_args()
    for url in publish_screenshots(
        args.source,
        topic=args.topic,
        commit=args.commit,
        env_path=args.env_file,
    ):
        print(url)


if __name__ == "__main__":
    main()
