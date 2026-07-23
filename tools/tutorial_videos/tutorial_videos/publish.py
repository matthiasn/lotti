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

from .tts.base import read_env_key

ENV_VARS = (
    "R2_ACCOUNT_ID",
    "R2_ACCESS_KEY_ID",
    "R2_SECRET_ACCESS_KEY",
    "R2_BUCKET_NAME",
    "R2_PUBLIC_BASE_URL",
)


class PublishError(RuntimeError):
    pass


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


def _correct_clock_skew_from(error) -> bool:
    """Best-effort fix for a host clock that has drifted without NTP/root
    access to correct it (SigV4 rejects any request signed more than ~15
    minutes off server time, as ``RequestTimeTooSkewed``). Reads the
    authoritative time from R2's own error-response ``Date`` header and
    monkey-patches ``botocore``'s signing clock so a retry succeeds.
    Returns True if a correction was applied (caller should retry once).
    """
    headers = error.response.get("ResponseMetadata", {}).get("HTTPHeaders", {})
    server_date = headers.get("date")
    if not server_date:
        return False

    import datetime as dt
    from email.utils import parsedate_to_datetime

    import botocore.auth

    server_now = parsedate_to_datetime(server_date)
    if server_now.tzinfo is not None:
        server_now = server_now.astimezone(dt.timezone.utc).replace(tzinfo=None)
    offset = server_now - dt.datetime.now(dt.timezone.utc).replace(tzinfo=None)

    real_get_current_datetime = botocore.auth.get_current_datetime

    def _corrected(remove_tzinfo=True):
        now = real_get_current_datetime(remove_tzinfo=False) + offset
        return now.replace(tzinfo=None) if remove_tzinfo else now

    botocore.auth.get_current_datetime = _corrected
    return True


def publish_video(env_path: Path, video_path: Path, key: str) -> str:
    """Uploads ``video_path`` to R2 under ``key`` and returns its public URL."""
    if not video_path.is_file():
        raise FileNotFoundError(f"{video_path} does not exist — build it first")

    from botocore.exceptions import BotoCoreError, ClientError

    values = {name: read_env_key(env_path, name) for name in ENV_VARS}
    client = _client(
        values["R2_ACCOUNT_ID"],
        values["R2_ACCESS_KEY_ID"],
        values["R2_SECRET_ACCESS_KEY"],
    )
    content_type = mimetypes.guess_type(video_path.name)[0] or "video/mp4"

    def _put() -> None:
        # A plain single-request put_object (not the high-level
        # upload_file/TransferManager helper) — these video files are well
        # under S3's single-PUT limit, and put_object raises the raw
        # ClientError directly instead of wrapping it in boto3's own
        # S3UploadFailedError, which would hide the structured error
        # response the clock-skew retry below depends on.
        with video_path.open("rb") as fh:
            client.put_object(
                Bucket=values["R2_BUCKET_NAME"],
                Key=key,
                Body=fh,
                ContentType=content_type,
            )

    try:
        _put()
    except ClientError as err:
        if (
            err.response.get("Error", {}).get("Code") == "RequestTimeTooSkewed"
            and _correct_clock_skew_from(err)
        ):
            try:
                _put()
            except (ClientError, BotoCoreError) as retry_err:
                raise PublishError(
                    f"R2 upload failed for {key} (after clock-skew retry): {retry_err}"
                ) from retry_err
        else:
            raise PublishError(f"R2 upload failed for {key}: {err}") from err
    except BotoCoreError as err:
        raise PublishError(f"R2 upload failed for {key}: {err}") from err
    return f"{values['R2_PUBLIC_BASE_URL'].rstrip('/')}/{key}"
