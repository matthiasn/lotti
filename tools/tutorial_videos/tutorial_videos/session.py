"""Crash-safe context managers for the recording session.

Each manager owns exactly one piece of host state and restores it on exit,
whatever happens inside:

* :class:`XvfbDisplay` — a dedicated virtual X display for the app.
* :class:`VirtualMic` — a PulseAudio/PipeWire null sink whose monitor becomes
  the default source (the app's `parecord`-based recorder reads the default
  source, so audio played into the sink is "the user speaking").
* :class:`ScreenCapture` — an ffmpeg x11grab process writing a
  lightly-compressed intermediate; records its own start epoch so the
  compositor can align the capture with the harness timeline
  (`timeline.json`'s ``zero_epoch_ms``).
"""

from __future__ import annotations

import os
import signal
import subprocess
import time
from pathlib import Path


class SessionError(RuntimeError):
    pass


def _run(cmd: list[str]) -> str:
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if result.returncode != 0:
        raise SessionError(f"{' '.join(cmd)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


class XvfbDisplay:
    """``Xvfb :N`` sized to the app window so the capture is exactly the app."""

    def __init__(self, display: str = ":99", size: str = "1280x720") -> None:
        self.display = display
        self.size = size
        self._process: subprocess.Popen[bytes] | None = None

    def __enter__(self) -> "XvfbDisplay":
        self._process = subprocess.Popen(
            ["Xvfb", self.display, "-screen", "0", f"{self.size}x24"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            probe = subprocess.run(
                ["xdpyinfo"],
                env={**os.environ, "DISPLAY": self.display},
                capture_output=True,
                check=False,
            )
            if probe.returncode == 0:
                return self
            if self._process.poll() is not None:
                break
            time.sleep(0.2)
        raise SessionError(f"Xvfb failed to come up on {self.display}")

    def __exit__(self, *_exc: object) -> None:
        if self._process is not None:
            self._process.terminate()
            self._process.wait(timeout=10)


class VirtualMic:
    """Null sink + default-source switch; restores the previous source."""

    def __init__(self, sink_name: str = "lotti_tutorial_mic") -> None:
        self.sink_name = sink_name
        self._module_id: str | None = None
        self._previous_source: str | None = None

    def __enter__(self) -> "VirtualMic":
        self._previous_source = _run(["pactl", "get-default-source"])
        self._module_id = _run(
            [
                "pactl",
                "load-module",
                "module-null-sink",
                f"sink_name={self.sink_name}",
                "sink_properties=device.description=LottiTutorialMic",
            ]
        )
        _run(["pactl", "set-default-source", f"{self.sink_name}.monitor"])
        return self

    def __exit__(self, *_exc: object) -> None:
        if self._previous_source:
            subprocess.run(
                ["pactl", "set-default-source", self._previous_source],
                check=False,
            )
        if self._module_id:
            subprocess.run(
                ["pactl", "unload-module", self._module_id], check=False
            )


class ScreenCapture:
    """ffmpeg x11grab of the whole (app-sized) virtual display."""

    def __init__(
        self,
        display: str,
        size: str,
        output: Path,
        framerate: int = 30,
    ) -> None:
        self.display = display
        self.size = size
        self.output = output
        self.framerate = framerate
        self.start_epoch_ms: int | None = None
        self._process: subprocess.Popen[bytes] | None = None

    def __enter__(self) -> "ScreenCapture":
        self.output.parent.mkdir(parents=True, exist_ok=True)
        self._process = subprocess.Popen(
            [
                "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                "-f", "x11grab",
                "-draw_mouse", "0",
                "-framerate", str(self.framerate),
                "-video_size", self.size,
                "-i", self.display,
                "-c:v", "libx264", "-preset", "ultrafast", "-crf", "18",
                "-pix_fmt", "yuv420p",
                str(self.output),
            ],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        # Close enough for A/V alignment: x11grab starts pulling frames
        # immediately; the harness timeline zero lands tens of seconds later.
        self.start_epoch_ms = int(time.time() * 1000)
        time.sleep(0.5)
        if self._process.poll() is not None:
            raise SessionError("ffmpeg capture terminated immediately")
        return self

    def __exit__(self, *_exc: object) -> None:
        if self._process is not None and self._process.poll() is None:
            # 'q'-less graceful stop: SIGINT lets ffmpeg finalize the file.
            self._process.send_signal(signal.SIGINT)
            try:
                self._process.wait(timeout=15)
            except subprocess.TimeoutExpired:
                self._process.terminate()
                self._process.wait(timeout=10)
