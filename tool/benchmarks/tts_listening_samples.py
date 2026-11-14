"""Listening samples for the ElevenLabs evaluation: neutral fixture texts only.

python3 -I tool/benchmarks/tts_listening_samples.py .env outdir
Writes <outdir>/<label>.mp3 and <outdir>/samples.json (label, model, voice, text).
"""
import json
import re
import subprocess
import sys
import urllib.request

env = dict(l.strip().split('=', 1) for l in open(sys.argv[1]) if '=' in l and not l.startswith('#'))
EL = env['ELEVEN_LABS_API_KEY'].strip('"\'')
MI = env.get('MISTRAL_API_KEY', '').strip('"\'')
out = sys.argv[2]

TAGGED = ('[sighs] Okay... three tasks slipped again this week. [warmly] But honestly? '
          "That's fine. You shipped the big one on Tuesday, [excited] and that was the hard part!")
PLAIN = re.sub(r'\[[^\]]+\]\s*', '', TAGGED)
GERMAN = ('Guten Morgen! Heute stehen zwei Aufgaben an. Die erste ist schnell erledigt, '
          'für die zweite solltest du dir etwas mehr Zeit nehmen.')
VOICES = {'Sarah': 'EXAVITQu4vr4xnSDxMaL', 'George': 'JBFqnCBsd6RMkjVDRZzb', 'River': 'SAz9YHcvj6GT2YYXdXww'}
TAG_MODELS = {'eleven_v4_turbo', 'eleven_v4', 'eleven_v3'}

jobs = []
for model in ['eleven_v4_turbo', 'eleven_v4', 'eleven_v3', 'eleven_multilingual_v2', 'eleven_flash_v2_5']:
    voices = VOICES if model in ('eleven_v4_turbo', 'eleven_v4') else {'Sarah': VOICES['Sarah']}
    for name, vid in voices.items():
        jobs.append((f'{model}_{name}_expressive', model, name, vid, TAGGED if model in TAG_MODELS else PLAIN))
for name, vid in VOICES.items():
    jobs.append((f'eleven_v4_turbo_{name}_german', 'eleven_v4_turbo', name, vid, GERMAN))
jobs.append(('eleven_multilingual_v2_Sarah_german', 'eleven_multilingual_v2', 'Sarah', VOICES['Sarah'], GERMAN))


def to_mp3(raw, label, rate=24000):
    subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-f', 's16le', '-ar', str(rate), '-ac', '1',
                    '-i', '-', '-b:a', '64k', f'{out}/{label}.mp3'], input=raw, check=True)


meta = []
for label, model, name, vid, text in jobs:
    req = urllib.request.Request(
        f'https://api.elevenlabs.io/v1/text-to-speech/{vid}?output_format=pcm_24000',
        data=json.dumps({'text': text, 'model_id': model}).encode(),
        headers={'xi-api-key': EL, 'Content-Type': 'application/json'})
    try:
        raw = urllib.request.urlopen(req, timeout=90).read()
    except urllib.error.HTTPError as e:
        print(label, 'failed', e.code, e.read()[:200]); continue
    to_mp3(raw, label)
    meta.append({'label': label, 'model': model, 'voice': name, 'voiceId': vid, 'text': text})
    print(label, len(raw) / 48000, 's')

# Voxtral, the current cloud voice: first English preset, as the app's default picks.
if MI:
    import base64
    vreq = urllib.request.Request('https://api.mistral.ai/v1/audio/voices?limit=100&type=all',
                                  headers={'Authorization': f'Bearer {MI}'})
    items = json.load(urllib.request.urlopen(vreq, timeout=30))
    items = items.get('items') or items.get('data') or items.get('voices')
    en = [v for v in items if 'en' in str(v.get('languages') or v.get('language') or '')] or items
    for text, kind in ((PLAIN, 'expressive'), (GERMAN, 'german')):
        body = {'model': 'voxtral-mini-tts-3-0', 'input': text, 'voice_id': en[0]['id'], 'response_format': 'wav'}
        r = urllib.request.Request('https://api.mistral.ai/v1/audio/speech', data=json.dumps(body).encode(),
                                   headers={'Authorization': f'Bearer {MI}', 'Content-Type': 'application/json'})
        raw = base64.b64decode(json.load(urllib.request.urlopen(r, timeout=90))['audio_data'])
        label = f'voxtral_{kind}'
        subprocess.run(['ffmpeg', '-loglevel', 'error', '-y', '-i', '-', '-b:a', '64k', f'{out}/{label}.mp3'], input=raw, check=True)
        meta.append({'label': label, 'model': 'voxtral-mini-tts-3-0', 'voice': en[0].get('name', en[0]['id']),
                     'voiceId': en[0]['id'], 'text': text})
        print(label, 'ok')
json.dump(meta, open(f'{out}/samples.json', 'w'), indent=2)
