"""OpenMontage-side compose driver.

Executed by the PINNED OpenMontage checkout's own `.venv/bin/python` with its
repo root on sys.path (see `compose.py`): reads a job JSON, runs
`AudioMixer full_mix` (narration clips placed at absolute timeline
timestamps + loudness normalization) and `VideoCompose compose` (trim the
screen capture to the timeline window, mux the mixed narration), and prints
a result JSON to stdout.

Job schema::

    {
      "tracks":  [{"path": ..., "start_seconds": ...}, ...],
      "capture": {"path": ..., "in_seconds": ..., "out_seconds": ...},
      "size":    {"width": 1280, "height": 720},
      "mixed_out":  "/abs/mixed.wav",
      "video_out":  "/abs/final.mp4"
    }

Kept dependency-free on the lotti side: everything OpenMontage-specific is
contained here, so bumping the pin only ever means revisiting this file.
"""

from __future__ import annotations

import json
import sys


def main() -> None:
    job = json.loads(sys.argv[1])

    from tools.audio.audio_mixer import AudioMixer
    from tools.video.video_compose import VideoCompose

    mix = AudioMixer().execute(
        {
            "operation": "full_mix",
            "tracks": [
                {
                    "path": track["path"],
                    "role": "speech",
                    "start_seconds": track["start_seconds"],
                }
                for track in job["tracks"]
            ],
            "ducking": {"enabled": False},
            "normalize": True,
            "loudnorm_target": -16,
            "output_path": job["mixed_out"],
        }
    )
    if not mix.success:
        raise SystemExit(f"audio_mixer failed: {mix.error}")

    capture = job["capture"]
    total = capture["out_seconds"] - capture["in_seconds"]
    compose = VideoCompose().execute(
        {
            "operation": "compose",
            "edit_decisions": {
                "cuts": [
                    {
                        "source": capture["path"],
                        "in_seconds": capture["in_seconds"],
                        "out_seconds": capture["out_seconds"],
                    }
                ],
                "metadata": {
                    "compose_target": {
                        "width": job["size"]["width"],
                        "height": job["size"]["height"],
                        "fit": "pad",
                    },
                    "total_duration_seconds": total,
                },
            },
            "audio_path": job["mixed_out"],
            "output_path": job["video_out"],
            "codec": "libx264",
            "crf": 20,
            "preset": "medium",
        }
    )
    if not compose.success:
        raise SystemExit(f"video_compose failed: {compose.error}")

    print(json.dumps({"video": job["video_out"], "mixed": job["mixed_out"]}))


if __name__ == "__main__":
    main()
