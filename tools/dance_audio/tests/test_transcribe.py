"""Tests for the dance_audio transcription tool.

Deliberately **torch-free**, like the beat-map tests: the only part of
transcribe.py that needs WhisperX / torch is ``_run_asr``, which these tests
monkeypatch. Everything else (schema assembly, time/score rounding, determinism,
the CLI window) runs on numpy + soundfile, so the suite needs neither whisperx
nor torch installed.
"""

import json

import numpy as np
import pytest

import transcribe

# WhisperX-shaped sample output (raw, unrounded). Text has stray whitespace and
# one word is left unaligned (None start/end/score) to exercise those branches.
_SEGMENTS = [
    {"start": 0.0, "end": 1.5, "text": " hello there"},
    {"start": 1.5, "end": 3.0, "text": "moving on "},
]
_WORDS = [
    {"word": "hello", "start": 0.0, "end": 0.6, "score": 0.9123},
    {"word": "there", "start": 0.6, "end": 1.5, "score": 0.88},
    {"word": "moving", "start": 1.5, "end": 2.2, "score": 0.7},
    {"word": "on", "start": 2.2, "end": 3.0, "score": None},
    {"word": "ad-lib", "start": None, "end": None, "score": None},
]


def _fake_asr(segments, words, *, lang="en", aligner="wav2vec2 (whisperx@test)"):
    """Build a stand-in for ``transcribe._run_asr`` returning fixed ASR output."""

    def _run(signal, sr, *, model, language=None):
        return {
            "language": lang,
            "aligner": aligner,
            "segments": segments,
            "words": words,
        }

    return _run


def _silence(seconds: float) -> np.ndarray:
    return np.zeros(int(transcribe.ASR_SR * seconds), dtype=np.float32)


@pytest.fixture(autouse=True)
def _guard_real_asr(monkeypatch):
    """Guarantee the suite never runs real WhisperX / torch inference.

    Mirrors the conftest guard for Beat This!: ``transcribe._run_asr`` is replaced
    with a raiser, so a test that forgets to stub it fails loudly here instead of
    trying to import whisperx (which CI does not install). Tests that need ASR
    output provide their own stub via ``monkeypatch.setattr`` (it wins over this).
    """

    def _no_real_inference(*args, **kwargs):
        raise AssertionError(
            "WhisperX inference must be mocked in tests "
            "(monkeypatch transcribe._run_asr); CI has no whisperx/torch."
        )

    monkeypatch.setattr(transcribe, "_run_asr", _no_real_inference)
    monkeypatch.setattr(transcribe, "_run_alignment", _no_real_inference)


class TestGuard:
    def test_unmocked_asr_raises(self):
        # The autouse guard makes an un-stubbed run fail loudly, not import torch.
        with pytest.raises(AssertionError, match="must be mocked"):
            transcribe.transcribe(_silence(1), transcribe.ASR_SR, audio_path="x.wav", model="base")


class TestLyrics:
    def test_parse_lyrics_tags_voice_and_section(self):
        text = "[Chorus]\nI've been moving (Ooh), moving\n[Verse]\nbein' honest"
        toks = transcribe._parse_lyrics(text)
        assert [t["word"] for t in toks] == [
            "I've",
            "been",
            "moving",
            "Ooh",
            "moving",
            "bein'",
            "honest",
        ]
        by_word = {t["word"]: t for t in toks}
        assert by_word["Ooh"]["voice"] == "background"
        assert by_word["moving"]["voice"] == "lead"
        assert by_word["Ooh"]["section"] == "chorus"
        assert by_word["honest"]["section"] == "verse"

    def test_transcribe_lyrics_force_aligns_and_tags_voice(self, monkeypatch):
        text = "[Chorus]\nhello (ooh)\nworld"
        aligned = [
            {"word": "hello", "start": 0.0, "end": 0.4, "score": 0.9},
            {"word": "ooh", "start": 0.4, "end": 0.6, "score": 0.8},
            {"word": "world", "start": 1.0, "end": 1.5, "score": 0.95},
        ]
        monkeypatch.setattr(
            transcribe,
            "_run_alignment",
            lambda signal, sr, words, *, language: aligned,
        )
        out = transcribe.transcribe_lyrics(
            _silence(2), transcribe.ASR_SR, audio_path="x.wav", lyrics=text
        )
        assert out["asr"]["model"] == "lyrics-aligned"
        assert [w["word"] for w in out["words"]] == ["hello", "ooh", "world"]
        assert [w["voice"] for w in out["words"]] == ["lead", "background", "lead"]
        assert out["words"][1]["start_sec"] == 0.4
        # Segments grouped per lyric line; the ad-lib stays on its lead line.
        assert [s["text"] for s in out["segments"]] == ["hello ooh", "world"]
        assert out["segments"][1]["voice"] == "lead"


class TestPureHelpers:
    def test_round_t_rounds_to_milliseconds_and_passes_none(self):
        assert transcribe._round_t(1.23456) == 1.235
        assert transcribe._round_t(None) is None


class TestTranscribe:
    def test_assembles_the_transcription_schema(self, monkeypatch):
        monkeypatch.setattr(transcribe, "_run_asr", _fake_asr(_SEGMENTS, _WORDS))
        out = transcribe.transcribe(
            _silence(3), transcribe.ASR_SR, audio_path="x.wav", model="base"
        )

        assert out["schema_version"] == "1.0"
        assert out["audio"] == {
            "path": "x.wav",
            "duration_sec": 3.0,
            "segment_start_sec": 0.0,
        }
        assert out["asr"] == {
            "model": "base",
            "language": "en",
            "aligner": "wav2vec2 (whisperx@test)",
            "created_utc": None,
        }

    def test_drops_trailing_boilerplate_hallucination(self, monkeypatch):
        segments = [
            {"start": 0.0, "end": 1.5, "text": "hello there"},
            {"start": 130.0, "end": 131.0, "text": "Thank you."},
        ]
        words = [
            {"word": "hello", "start": 0.0, "end": 0.6, "score": 0.9},
            {"word": "there", "start": 0.6, "end": 1.5, "score": 0.9},
            {"word": "Thank", "start": 130.0, "end": 130.5, "score": 0.3},
            {"word": "you.", "start": 130.5, "end": 131.0, "score": 0.3},
        ]
        monkeypatch.setattr(transcribe, "_run_asr", _fake_asr(segments, words))
        out = transcribe.transcribe(
            _silence(1), transcribe.ASR_SR, audio_path="x.wav", model="base"
        )
        # The trailing "Thank you." line and its words are gone; real lyrics stay.
        assert [s["text"] for s in out["segments"]] == ["hello there"]
        assert [w["word"] for w in out["words"]] == ["hello", "there"]

    def test_segments_are_stripped_and_rounded(self, monkeypatch):
        monkeypatch.setattr(transcribe, "_run_asr", _fake_asr(_SEGMENTS, _WORDS))
        out = transcribe.transcribe(
            _silence(3), transcribe.ASR_SR, audio_path="x.wav", model="base"
        )
        assert out["segments"] == [
            {"start_sec": 0.0, "end_sec": 1.5, "text": "hello there"},
            {"start_sec": 1.5, "end_sec": 3.0, "text": "moving on"},
        ]

    def test_words_carry_timestamps_scores_and_unaligned_nones(self, monkeypatch):
        monkeypatch.setattr(transcribe, "_run_asr", _fake_asr(_SEGMENTS, _WORDS))
        out = transcribe.transcribe(
            _silence(3), transcribe.ASR_SR, audio_path="x.wav", model="base"
        )
        words = out["words"]
        assert [w["word"] for w in words] == ["hello", "there", "moving", "on", "ad-lib"]
        # score rounded to 3 dp.
        assert words[0] == {"word": "hello", "start_sec": 0.0, "end_sec": 0.6, "score": 0.912}
        # aligned word with a missing score keeps None for the score only.
        assert words[3] == {"word": "on", "start_sec": 2.2, "end_sec": 3.0, "score": None}
        # fully unaligned token: all of start/end/score are None.
        assert words[4] == {
            "word": "ad-lib",
            "start_sec": None,
            "end_sec": None,
            "score": None,
        }

    def test_output_is_deterministic_without_a_stamp(self, monkeypatch):
        monkeypatch.setattr(transcribe, "_run_asr", _fake_asr(_SEGMENTS, _WORDS))
        sig = _silence(2)
        first = transcribe.transcribe(sig, transcribe.ASR_SR, audio_path="x.wav", model="base")
        second = transcribe.transcribe(sig, transcribe.ASR_SR, audio_path="x.wav", model="base")
        assert first["asr"]["created_utc"] is None
        assert json.dumps(first) == json.dumps(second)

    def test_stamp_is_embedded_when_requested(self, monkeypatch):
        monkeypatch.setattr(transcribe, "_run_asr", _fake_asr(_SEGMENTS, _WORDS))
        out = transcribe.transcribe(
            _silence(1),
            transcribe.ASR_SR,
            audio_path="x.wav",
            model="base",
            stamp="2026-06-28T00:00:00+00:00",
        )
        assert out["asr"]["created_utc"] == "2026-06-28T00:00:00+00:00"

    def test_records_segment_start_for_a_mid_song_window(self, monkeypatch):
        monkeypatch.setattr(transcribe, "_run_asr", _fake_asr(_SEGMENTS, _WORDS))
        out = transcribe.transcribe(
            _silence(3),
            transcribe.ASR_SR,
            audio_path="x.wav",
            model="base",
            segment_start=72.5,
        )
        assert out["audio"]["segment_start_sec"] == 72.5
        # Word times stay relative to the segment (0-based), not shifted by start.
        assert out["words"][0]["start_sec"] == 0.0


class TestCli:
    def test_writes_a_json_file(self, monkeypatch, tmp_path):
        import soundfile as sf

        monkeypatch.setattr(transcribe, "_run_asr", _fake_asr(_SEGMENTS, _WORDS))
        wav = tmp_path / "a.wav"
        sf.write(wav, _silence(2), transcribe.ASR_SR)
        out = tmp_path / "words.json"

        assert transcribe.main([str(wav), "-o", str(out), "--model", "base"]) == 0
        data = json.loads(out.read_text())
        assert data["audio"]["path"] == str(wav)
        assert data["asr"]["model"] == "base"
        assert [w["word"] for w in data["words"]] == [
            "hello",
            "there",
            "moving",
            "on",
            "ad-lib",
        ]
        assert len(data["segments"]) == 2

    def test_prints_json_to_stdout_without_out(self, monkeypatch, tmp_path, capsys):
        import soundfile as sf

        monkeypatch.setattr(transcribe, "_run_asr", _fake_asr(_SEGMENTS, _WORDS))
        wav = tmp_path / "a.wav"
        sf.write(wav, _silence(1), transcribe.ASR_SR)

        assert transcribe.main([str(wav)]) == 0
        data = json.loads(capsys.readouterr().out)
        assert data["schema_version"] == "1.0"
        assert data["asr"]["language"] == "en"


class TestSegment:
    def test_load_audio_offset_and_duration_select_a_window(self, tmp_path):
        import soundfile as sf

        sf.write(tmp_path / "c.wav", _silence(8), transcribe.ASR_SR)
        y, sr = transcribe.load_audio(str(tmp_path / "c.wav"), offset=2.0, duration=3.0)
        assert sr == transcribe.ASR_SR
        assert abs(len(y) / sr - 3.0) < 0.05  # ~3 s window from offset 2 s

    def test_cli_start_and_duration_decode_the_window(self, monkeypatch, tmp_path):
        import soundfile as sf

        monkeypatch.setattr(transcribe, "_run_asr", _fake_asr(_SEGMENTS, _WORDS))
        wav = tmp_path / "c.wav"
        sf.write(wav, _silence(8), transcribe.ASR_SR)
        out = tmp_path / "w.json"

        assert transcribe.main([str(wav), "--start", "2", "--duration", "3", "-o", str(out)]) == 0
        data = json.loads(out.read_text())
        assert data["audio"]["segment_start_sec"] == 2.0
        assert abs(data["audio"]["duration_sec"] - 3.0) < 0.05
