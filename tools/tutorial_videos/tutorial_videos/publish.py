"""Publishes a finished tutorial video to Cloudflare R2 for docs-site embedding.

R2 is S3-compatible, so this uses ``boto3`` (the one dependency in this
otherwise stdlib-only toolchain — correctly signing authenticated S3
requests by hand is a real source of subtle bugs, unlike the simple
unauthenticated-by-API-key calls the TTS adapters make). Credentials come
from the repo ``.env``, matching ``GEMINI_API_KEY``/``MELIOUS_API_KEY``.

Setup (one-time, in the Cloudflare dashboard): R2 -> Manage R2 API Tokens ->
Create API Token, scoped to the target bucket, permission "Object Read &
Write". Also enable the bucket's public r2.dev URL (R2 -> bucket ->
Settings -> Public Access) so uploaded videos are directly embeddable.
"""

from __future__ import annotations

import mimetypes
from pathlib import Path

from .tts.gemini import read_env_key

ENV_VARS = (
    "R2_ACCOUNT_ID",
    "R2_ACCESS_KEY_ID",
    "R2_SECRET_ACCESS_KEY",
    "R2_BUCKET_NAME",
    "R2_PUBLIC_BASE_URL",
)


def _client(account_id: str, access_key_id: str, secret_access_key: str):
    # Imported lazily so `validate`/`tts`/`build` never require boto3 to be
    # installed — only `publish` does.
    import boto3

    return boto3.client(
        "s3",
        endpoint_url=f"https://{account_id}.r2.cloudflarestorage.com",
        aws_access_key_id=access_key_id,
        aws_secret_access_key=secret_access_key,
        region_name="auto",
    )


def publish_video(env_path: Path, video_path: Path, key: str) -> str:
    """Uploads ``video_path`` to R2 under ``key`` and returns its public URL."""
    if not video_path.is_file():
        raise FileNotFoundError(f"{video_path} does not exist — build it first")

    values = {name: read_env_key(env_path, name) for name in ENV_VARS}
    client = _client(
        values["R2_ACCOUNT_ID"],
        values["R2_ACCESS_KEY_ID"],
        values["R2_SECRET_ACCESS_KEY"],
    )
    content_type = mimetypes.guess_type(video_path.name)[0] or "video/mp4"
    client.upload_file(
        str(video_path),
        values["R2_BUCKET_NAME"],
        key,
        ExtraArgs={"ContentType": content_type},
    )
    return f"{values['R2_PUBLIC_BASE_URL'].rstrip('/')}/{key}"
