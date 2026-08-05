from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

from pr_screenshot_publish import (
    CACHE_CONTROL,
    PublishError,
    discover_uploads,
    publish_screenshots,
)


class _MissingObjectError(Exception):
    def __init__(self):
        super().__init__()
        self.response = {"Error": {"Code": "404"}}


class _PreconditionFailedError(Exception):
    def __init__(self):
        super().__init__()
        self.response = {"Error": {"Code": "412"}}


class _FakeClient:
    def __init__(
        self,
        existing: dict[str, str] | None = None,
        concurrent: dict[str, str] | None = None,
    ):
        self.existing = existing or {}
        self.concurrent = concurrent or {}
        self.puts: list[dict[str, object]] = []

    def head_object(self, *, Bucket: str, Key: str):
        if Key not in self.existing:
            raise _MissingObjectError
        return {"Metadata": {"sha256": self.existing[Key]}}

    def put_object(self, **kwargs):
        key = kwargs["Key"]
        if key in self.concurrent:
            self.existing[key] = self.concurrent[key]
            raise _PreconditionFailedError
        self.puts.append(kwargs)


class PrScreenshotPublishTest(unittest.TestCase):
    def setUp(self):
        self.temp_dir = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp_dir.cleanup)
        self.root = Path(self.temp_dir.name)
        self.source = self.root / "captures"
        (self.source / "before").mkdir(parents=True)
        (self.source / "after").mkdir()
        (self.source / "before" / "viewer.png").write_bytes(b"before")
        (self.source / "after" / "viewer.png").write_bytes(b"after")
        self.env_path = self.root / ".env"
        self.env_path.write_text(
            "\n".join(
                (
                    "R2_ACCOUNT_ID=account",
                    "R2_ACCESS_KEY_ID=access",
                    "R2_SECRET_ACCESS_KEY=secret",
                    "R2_BUCKET_NAME=bucket",
                    "R2_PUBLIC_BASE_URL=https://media.example/",
                )
            ),
            encoding="utf-8",
        )
        self.commit = "a" * 40

    def test_discovers_before_and_after_under_commit_prefix(self):
        uploads = discover_uploads(
            self.source,
            topic="ontology-viewer",
            commit=self.commit,
        )

        self.assertEqual(
            [upload.key for upload in uploads],
            [
                f"pr-screenshots/ontology-viewer/{self.commit}/after/viewer.png",
                f"pr-screenshots/ontology-viewer/{self.commit}/before/viewer.png",
            ],
        )
        self.assertNotEqual(uploads[0].sha256, uploads[1].sha256)

    def test_uploads_png_with_immutable_headers_and_hash_metadata(self):
        client = _FakeClient()

        urls = publish_screenshots(
            self.source,
            topic="ontology-viewer",
            commit=self.commit,
            env_path=self.env_path,
            client_factory=lambda _: client,
        )

        self.assertEqual(len(client.puts), 2)
        self.assertEqual(
            urls[0],
            f"https://media.example/pr-screenshots/ontology-viewer/"
            f"{self.commit}/after/viewer.png",
        )
        for upload in client.puts:
            self.assertEqual(upload["ContentType"], "image/png")
            self.assertEqual(upload["CacheControl"], CACHE_CONTROL)
            self.assertRegex(upload["Metadata"]["sha256"], r"^[0-9a-f]{64}$")
            self.assertEqual(upload["IfNoneMatch"], "*")

    def test_rejects_missing_before_or_after_state(self):
        (self.source / "after" / "viewer.png").unlink()

        with self.assertRaisesRegex(PublishError, "Both before/ and after"):
            discover_uploads(
                self.source,
                topic="ontology-viewer",
                commit=self.commit,
            )

    def test_rejects_mismatched_pair_filenames(self):
        (self.source / "after" / "viewer.png").rename(
            self.source / "after" / "different.png"
        )

        with self.assertRaisesRegex(PublishError, "surfaces must match"):
            discover_uploads(
                self.source,
                topic="ontology-viewer",
                commit=self.commit,
            )

    def test_accepts_state_suffixes_as_one_surface_pair(self):
        (self.source / "before" / "viewer.png").rename(
            self.source / "before" / "viewer_before.png"
        )
        (self.source / "after" / "viewer.png").rename(
            self.source / "after" / "viewer_after.png"
        )

        uploads = discover_uploads(
            self.source,
            topic="ontology-viewer",
            commit=self.commit,
        )

        self.assertEqual(
            [upload.path.name for upload in uploads],
            ["viewer_after.png", "viewer_before.png"],
        )

    def test_rejects_duplicate_normalized_surface(self):
        (self.source / "before" / "viewer_before.png").write_bytes(b"duplicate")

        with self.assertRaisesRegex(PublishError, "Duplicate before"):
            discover_uploads(
                self.source,
                topic="ontology-viewer",
                commit=self.commit,
            )

    def test_same_content_is_idempotent_without_another_put(self):
        uploads = discover_uploads(
            self.source,
            topic="ontology-viewer",
            commit=self.commit,
        )
        client = _FakeClient(
            {upload.key: upload.sha256 for upload in uploads},
        )

        publish_screenshots(
            self.source,
            topic="ontology-viewer",
            commit=self.commit,
            env_path=self.env_path,
            client_factory=lambda _: client,
        )

        self.assertEqual(client.puts, [])

    def test_refuses_to_overwrite_different_content(self):
        upload = discover_uploads(
            self.source,
            topic="ontology-viewer",
            commit=self.commit,
        )[0]
        client = _FakeClient({upload.key: "different"})

        with self.assertRaisesRegex(PublishError, "Refusing to overwrite"):
            publish_screenshots(
                self.source,
                topic="ontology-viewer",
                commit=self.commit,
                env_path=self.env_path,
                client_factory=lambda _: client,
            )

        self.assertEqual(client.puts, [])

    def test_accepts_matching_concurrent_create(self):
        uploads = discover_uploads(
            self.source,
            topic="ontology-viewer",
            commit=self.commit,
        )
        concurrent = {upload.key: upload.sha256 for upload in uploads}
        client = _FakeClient(concurrent=concurrent)

        urls = publish_screenshots(
            self.source,
            topic="ontology-viewer",
            commit=self.commit,
            env_path=self.env_path,
            client_factory=lambda _: client,
        )

        self.assertEqual(len(urls), 2)
        self.assertEqual(client.puts, [])

    def test_rejects_mismatched_concurrent_create(self):
        uploads = discover_uploads(
            self.source,
            topic="ontology-viewer",
            commit=self.commit,
        )
        client = _FakeClient(
            concurrent={upload.key: "different" for upload in uploads}
        )

        with self.assertRaisesRegex(PublishError, "concurrent overwrite"):
            publish_screenshots(
                self.source,
                topic="ontology-viewer",
                commit=self.commit,
                env_path=self.env_path,
                client_factory=lambda _: client,
            )

        self.assertEqual(client.puts, [])

    def test_rejects_noncanonical_topic_and_short_commit(self):
        with self.assertRaisesRegex(PublishError, "Topic"):
            discover_uploads(self.source, topic="Bad Topic", commit=self.commit)
        with self.assertRaisesRegex(PublishError, "Commit"):
            discover_uploads(self.source, topic="good-topic", commit="abc123")


if __name__ == "__main__":
    unittest.main()
