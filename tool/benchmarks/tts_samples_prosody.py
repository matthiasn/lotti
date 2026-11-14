"""Objective proxies for the listening samples (run with uv + numpy):
  - pitch spread: F0 of voiced 40 ms frames (autocorrelation, 70–400 Hz),
    as the standard deviation and the 10–90 % range in semitones;
  - whether audio tags were read out, from a Voxtral transcript.
uv run --with numpy python -I tool/benchmarks/tts_samples_prosody.py .env outdir
"""
import json
import subprocess
import sys
import urllib.request
import uuid

import numpy as np

env = dict(l.strip().split('=', 1) for l in open(sys.argv[1]) if '=' in l and not l.startswith('#'))
MI = env['MISTRAL_API_KEY'].strip('"\'')
out = sys.argv[2]
SR = 16000


def pcm(path):
    raw = subprocess.run(['ffmpeg', '-loglevel', 'error', '-i', path, '-f', 'f32le', '-ac', '1', '-ar', str(SR), '-'],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def pitch_track(x):
    n, hop = int(0.04 * SR), int(0.01 * SR)
    lo, hi = SR // 400, SR // 70
    rms_all = np.sqrt(np.mean(x ** 2))
    f0 = []
    for i in range(0, len(x) - n, hop):
        f = x[i:i + n] * np.hanning(n)
        if np.sqrt(np.mean(f ** 2)) < 0.3 * rms_all:
            continue
        ac = np.correlate(f, f, 'full')[n - 1:]
        if ac[0] <= 0:
            continue
        ac = ac / ac[0]
        lag = lo + int(np.argmax(ac[lo:hi]))
        if ac[lag] > 0.5:
            f0.append(SR / lag)
    f0 = np.array(f0)
    st = 12 * np.log2(f0 / np.median(f0))
    return float(np.std(st)), float(np.percentile(st, 90) - np.percentile(st, 10)), len(f0)


def transcribe(path):
    boundary = uuid.uuid4().hex
    data = open(path, 'rb').read()
    body = (f'--{boundary}\r\nContent-Disposition: form-data; name="model"\r\n\r\nvoxtral-mini-transcribe-3-0\r\n'
            f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="a.mp3"\r\n'
            f'Content-Type: audio/mpeg\r\n\r\n').encode() + data + f'\r\n--{boundary}--\r\n'.encode()
    req = urllib.request.Request('https://api.mistral.ai/v1/audio/transcriptions', data=body, headers={
        'Authorization': f'Bearer {MI}', 'Content-Type': f'multipart/form-data; boundary={boundary}'})
    return json.load(urllib.request.urlopen(req, timeout=60)).get('text', '').strip()


# Self-check: a steady 200 Hz tone has no pitch spread.
_t = np.arange(SR) / SR
_sd, _rng, _n = pitch_track((0.5 * np.sin(2 * np.pi * 200 * _t)).astype(np.float32))
assert _n > 50 and _sd < 0.2 and _rng < 0.5, (_sd, _rng, _n)

meta = json.load(open(f'{out}/samples.json'))
for m in meta:
    path = f"{out}/{m['label']}.mp3"
    x = pcm(path)
    std, rng, frames = pitch_track(x)
    text = transcribe(path)
    spoken_tags = [t for t in ('sigh', 'warmly', 'excited') if t in text.lower()]
    m.update({'seconds': round(len(x) / SR, 2), 'f0StdSemitones': round(std, 2), 'f0RangeSemitones': round(rng, 1),
              'voicedFrames': frames, 'transcript': text, 'tagsReadOut': spoken_tags})
    print(f"{m['label']:42s} {m['seconds']:5.1f}s  F0 sd {std:4.2f} st  p10–p90 {rng:4.1f} st  tags read: {spoken_tags}")
json.dump(meta, open(f'{out}/samples.json', 'w'), indent=2, ensure_ascii=False)
