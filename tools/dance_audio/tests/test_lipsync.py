"""Tests for the Rhubarb lip-sync wrapper.

Binary-free: the only function that runs the rhubarb binary (``_run_rhubarb``) is
monkeypatched, so the suite needs just numpy + soundfile — no rhubarb build and
no audio model. An autouse guard makes an un-stubbed run fail loudly instead of
shelling out to a binary CI doesn't have.
"""

import json

import numpy as np
import pytest

import lipsync

# Rhubarb-shaped machine-readable JSON (the subset we consume).
_RH = {
    "metadata": {"soundFile": "x.wav", "duration": 2.0},
    "mouthCues": [
        {"start": 0.0, "end": 0.5, "value": "A"},
        {"start": 0.5, "end": 1.0, "value": "D"},
        {"start": 1.0, "end": 2.0, "value": "G"},
    ],
}


def _fake_rhubarb(raw=_RH):
    def _run(wav_path, *, recognizer, dialog_path, rhubarb_bin):
        return raw

    return _run


def _silence(seconds: float) -> np.ndarray:
    return np.zeros(int(lipsync.CUE_SR * seconds), dtype=np.float32)


@pytest.fixture(autouse=True)
def _guard_real_rhubarb(monkeypatch):
    def _no_real_run(*args, **kwargs):
        raise AssertionError(
            "rhubarb must be mocked in tests (monkeypatch lipsync._run_rhubarb); "
            "CI has no rhubarb binary."
        )

    monkeypatch.setattr(lipsync, "_run_rhubarb", _no_real_run)


class TestGuard:
    def test_unmocked_run_raises(self):
        with pytest.raises(AssertionError, match="must be mocked"):
            lipsync.lipsync(_silence(1), lipsync.CUE_SR, audio_path="x.wav")


class TestDialogText:
    def test_strips_sections_and_parens_keeping_words(self):
        text = "[Chorus]\nI've been moving (Ooh), moving\n\n[Verse]\nbein' honest"
        assert lipsync.dialog_text(text) == "I've been moving Ooh, moving\nbein' honest"


class TestLipsync:
    def test_assembles_cue_schema(self, monkeypatch):
        monkeypatch.setattr(lipsync, "_run_rhubarb", _fake_rhubarb())
        out = lipsync.lipsync(
            _silence(2), lipsync.CUE_SR, audio_path="x.wav", recognizer="phonetic"
        )
        assert out["schema_version"] == "1.0"
        assert out["audio"] == {
            "path": "x.wav",
            "duration_sec": 2.0,
            "segment_start_sec": 0.0,
        }
        assert out["lipsync"] == {
            "engine": "rhubarb",
            "recognizer": "phonetic",
            "shapes": "ABCDEFGHX",
            "created_utc": None,
        }
        assert out["cues"] == [
            {"start_sec": 0.0, "end_sec": 0.5, "shape": "A"},
            {"start_sec": 0.5, "end_sec": 1.0, "shape": "D"},
            {"start_sec": 1.0, "end_sec": 2.0, "shape": "G"},
        ]

    def test_records_segment_start_and_stamp(self, monkeypatch):
        monkeypatch.setattr(lipsync, "_run_rhubarb", _fake_rhubarb())
        out = lipsync.lipsync(
            _silence(2),
            lipsync.CUE_SR,
            audio_path="x.wav",
            segment_start=72.5,
            stamp="2026-06-28T00:00:00+00:00",
        )
        assert out["audio"]["segment_start_sec"] == 72.5
        assert out["lipsync"]["created_utc"] == "2026-06-28T00:00:00+00:00"

    def test_output_is_deterministic_without_a_stamp(self, monkeypatch):
        monkeypatch.setattr(lipsync, "_run_rhubarb", _fake_rhubarb())
        a = lipsync.lipsync(_silence(1), lipsync.CUE_SR, audio_path="x.wav")
        b = lipsync.lipsync(_silence(1), lipsync.CUE_SR, audio_path="x.wav")
        assert a["lipsync"]["created_utc"] is None
        assert json.dumps(a) == json.dumps(b)

    def test_rounds_cue_times_to_milliseconds(self, monkeypatch):
        raw = {"mouthCues": [{"start": 0.123456, "end": 0.654321, "value": "C"}]}
        monkeypatch.setattr(lipsync, "_run_rhubarb", _fake_rhubarb(raw))
        out = lipsync.lipsync(_silence(1), lipsync.CUE_SR, audio_path="x.wav")
        assert out["cues"][0] == {"start_sec": 0.123, "end_sec": 0.654, "shape": "C"}

    def test_dialog_is_written_and_passed_through(self, monkeypatch):
        seen = {}

        def _run(wav_path, *, recognizer, dialog_path, rhubarb_bin):
            seen["dialog_path"] = dialog_path
            return _RH

        monkeypatch.setattr(lipsync, "_run_rhubarb", _run)
        lipsync.lipsync(_silence(1), lipsync.CUE_SR, audio_path="x.wav", dialog="hello world")
        assert seen["dialog_path"] is not None

    def test_no_dialog_means_no_dialog_file(self, monkeypatch):
        seen = {}

        def _run(wav_path, *, recognizer, dialog_path, rhubarb_bin):
            seen["dialog_path"] = dialog_path
            return _RH

        monkeypatch.setattr(lipsync, "_run_rhubarb", _run)
        lipsync.lipsync(_silence(1), lipsync.CUE_SR, audio_path="x.wav")
        assert seen["dialog_path"] is None


class TestCli:
    def test_writes_a_json_file(self, monkeypatch, tmp_path):
        import soundfile as sf

        monkeypatch.setattr(lipsync, "_run_rhubarb", _fake_rhubarb())
        wav = tmp_path / "a.wav"
        sf.write(wav, _silence(2), lipsync.CUE_SR)
        out = tmp_path / "cues.json"
        assert lipsync.main([str(wav), "-o", str(out)]) == 0
        data = json.loads(out.read_text())
        assert [c["shape"] for c in data["cues"]] == ["A", "D", "G"]

    def test_prints_json_to_stdout_without_out(self, monkeypatch, tmp_path, capsys):
        import soundfile as sf

        monkeypatch.setattr(lipsync, "_run_rhubarb", _fake_rhubarb())
        wav = tmp_path / "a.wav"
        sf.write(wav, _silence(1), lipsync.CUE_SR)
        assert lipsync.main([str(wav)]) == 0
        data = json.loads(capsys.readouterr().out)
        assert data["lipsync"]["engine"] == "rhubarb"


class TestSegment:
    def test_load_audio_offset_and_duration_select_a_window(self, tmp_path):
        import soundfile as sf

        sf.write(tmp_path / "c.wav", _silence(8), lipsync.CUE_SR)
        y, sr = lipsync.load_audio(str(tmp_path / "c.wav"), offset=2.0, duration=3.0)
        assert sr == lipsync.CUE_SR
        assert abs(len(y) / sr - 3.0) < 0.05
