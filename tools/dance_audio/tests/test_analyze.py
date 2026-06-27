"""Tests for the dance_audio beat-map tool.

These are deliberately **torch-free**: the only part of analyze.py that needs
Beat This! / torch is ``_run_beat_this``, which the tests monkeypatch. Everything
else (schema assembly, bar-position assignment, tempo segmentation, the librosa
cross-check) runs on a synthetic click signal with just numpy + librosa.
"""

import json

import numpy as np
import pytest

import analyze


def _fake_beat_this(beats, downbeats):
    """Build a stand-in for ``analyze._run_beat_this`` returning fixed arrays."""

    def _run(signal, sr, *, dbn=False):
        return np.asarray(beats, dtype=float), np.asarray(downbeats, dtype=float)

    return _run


class TestPureHelpers:
    def test_tempo_segments_constant_is_a_single_segment(self):
        beats = np.arange(8) * 0.5  # steady 120 BPM
        segments = analyze._tempo_segments(beats)
        assert segments == [
            {"start_beat": 0, "start_time_sec": 0.0, "bpm": 120.0},
        ]

    def test_tempo_segments_splits_on_a_tempo_change(self):
        # four beats at 0.5 s (120 BPM) then three at 0.4 s (150 BPM).
        beats = np.array([0, 0.5, 1.0, 1.5, 2.0, 2.4, 2.8, 3.2])
        segments = analyze._tempo_segments(beats)
        assert [s["bpm"] for s in segments] == [120.0, 150.0]
        assert [s["start_beat"] for s in segments] == [0, 4]

    def test_beat_confidence_is_high_when_steady(self):
        conf = analyze._beat_confidence(np.array([0.5, 0.5, 0.5, 0.5]), 0.5)
        assert conf.shape == (5,)
        assert np.all(conf > 0.99)

    def test_beat_confidence_drops_around_a_local_outlier(self):
        # the third inter-beat interval is long; the two beats it touches dip.
        conf = analyze._beat_confidence(np.array([0.5, 0.5, 0.8, 0.5]), 0.5)
        assert conf[2] < 0.8
        assert conf[3] < 0.8
        assert conf[0] > 0.99

    def test_time_signature_numerator_reads_four_on_four(self):
        beats = np.arange(16) * 0.5
        downbeats = beats[::4]
        assert analyze._time_signature_numerator(beats, downbeats) == 4

    def test_time_signature_numerator_defaults_to_four_without_downbeats(self):
        beats = np.arange(8) * 0.5
        assert analyze._time_signature_numerator(beats, np.array([])) == 4

    def test_match_respects_the_tolerance(self):
        downbeats = np.array([0.0, 2.0, 4.0])
        assert analyze._match(2.01, downbeats) is True  # within 0.03 s
        assert analyze._match(2.1, downbeats) is False  # outside
        assert analyze._match(1.0, np.array([])) is False


class TestAnalyze:
    def test_assembles_the_beat_map_schema(self, monkeypatch, steady_grid):
        beats, downbeats = steady_grid
        monkeypatch.setattr(analyze, "_run_beat_this", _fake_beat_this(beats, downbeats))
        beatmap = analyze.analyze(
            analyze._synth_click(bpm=120, n_beats=16),
            analyze.ANALYSIS_SR,
            audio_path="x.wav",
        )

        assert beatmap["schema_version"] == "1.0"
        assert beatmap["tempo"]["global_bpm"] == 120.0
        assert beatmap["tempo"]["is_variable"] is False
        assert beatmap["time_signature"]["numerator"] == 4
        # Bar positions cycle 1..4 and downbeats land on the "1".
        assert [b["beat_in_bar"] for b in beatmap["beats"][:8]] == [1, 2, 3, 4, 1, 2, 3, 4]
        assert beatmap["beats"][0]["is_downbeat"] is True
        assert beatmap["beats"][1]["is_downbeat"] is False
        assert beatmap["downbeats_sec"][:2] == [0.0, 2.0]
        assert beatmap["loop"] == {"length_beats": 8, "anchor_downbeat_index": 0}

    def test_includes_a_normalized_waveform(self, monkeypatch, steady_grid):
        beats, downbeats = steady_grid
        monkeypatch.setattr(analyze, "_run_beat_this", _fake_beat_this(beats, downbeats))
        beatmap = analyze.analyze(
            analyze._synth_click(),
            analyze.ANALYSIS_SR,
            audio_path="x.wav",
        )
        wave = beatmap["waveform"]
        assert isinstance(wave, list) and len(wave) > 0
        assert all(0.0 <= v <= 1.0 for v in wave)
        assert max(wave) == 1.0  # normalized to the loudest bucket

    def test_output_is_deterministic_without_a_stamp(self, monkeypatch, steady_grid):
        beats, downbeats = steady_grid
        monkeypatch.setattr(analyze, "_run_beat_this", _fake_beat_this(beats, downbeats))
        signal = analyze._synth_click()
        first = analyze.analyze(signal, analyze.ANALYSIS_SR, audio_path="x.wav")
        second = analyze.analyze(signal, analyze.ANALYSIS_SR, audio_path="x.wav")
        assert first["analysis"]["created_utc"] is None
        assert json.dumps(first) == json.dumps(second)

    def test_raises_when_no_beats_are_found(self, monkeypatch):
        monkeypatch.setattr(analyze, "_run_beat_this", _fake_beat_this([], []))
        with pytest.raises(SystemExit):
            analyze.analyze(analyze._synth_click(), analyze.ANALYSIS_SR, audio_path="x.wav")


class TestCli:
    def test_writes_a_json_file(self, monkeypatch, tmp_path, steady_grid):
        import soundfile as sf

        beats, downbeats = steady_grid
        monkeypatch.setattr(analyze, "_run_beat_this", _fake_beat_this(beats, downbeats))
        wav = tmp_path / "click.wav"
        sf.write(wav, analyze._synth_click(), analyze.ANALYSIS_SR)
        out = tmp_path / "beatmap.json"

        assert analyze.main([str(wav), "-o", str(out)]) == 0
        data = json.loads(out.read_text())
        assert data["audio"]["path"] == str(wav)
        assert len(data["beats"]) == len(beats)

    def test_selftest_subcommand_passes(self, monkeypatch, steady_grid):
        beats, downbeats = steady_grid
        monkeypatch.setattr(analyze, "_run_beat_this", _fake_beat_this(beats, downbeats))
        # The synthetic-click self-test asserts the beat grid is recovered; with a
        # stubbed tracker it must report success (exit 0) without touching torch.
        assert analyze.main(["--selftest"]) == 0


class TestSegment:
    def test_load_audio_offset_and_duration_select_a_window(self, tmp_path):
        import soundfile as sf

        sf.write(
            tmp_path / "c.wav",
            analyze._synth_click(bpm=120, n_beats=16),  # 8 s of audio
            analyze.ANALYSIS_SR,
        )
        y, sr = analyze.load_audio(str(tmp_path / "c.wav"), offset=2.0, duration=3.0)
        assert sr == analyze.ANALYSIS_SR
        assert abs(len(y) / sr - 3.0) < 0.05  # ~3 s window from offset 2 s

    def test_analyze_records_the_segment_start(self, monkeypatch, steady_grid):
        beats, downbeats = steady_grid
        monkeypatch.setattr(analyze, "_run_beat_this", _fake_beat_this(beats, downbeats))
        beatmap = analyze.analyze(
            analyze._synth_click(),
            analyze.ANALYSIS_SR,
            audio_path="x.wav",
            segment_start=72.5,
        )
        assert beatmap["audio"]["segment_start_sec"] == 72.5
        # Beat times stay relative to the segment (0-based), not shifted by start.
        assert beatmap["beats"][0]["time_sec"] == 0.0
