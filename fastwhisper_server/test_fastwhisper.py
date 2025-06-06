from fastapi import FastAPI
from pydantic import BaseModel
import base64
import io
import requests
import sys

app = FastAPI()

class AudioInput(BaseModel):
    audio: str
    model: str
    language: str

@app.post("/transcribe")
def transcribe(input: AudioInput):
    audio_bytes = base64.b64decode(input.audio)
    audio_stream = io.BytesIO(audio_bytes)

    # Example: use audio_stream with whisper or faster-whisper
    from faster_whisper import WhisperModel
    model = WhisperModel(input.model)
    segments, _ = model.transcribe(audio_stream, language=input.language)

    result = []
    for segment in segments:
        result.append(segment.text)

    return {"transcription": result}

def transcribe_audio(audio_path):
    # Read the audio file and encode as base64
    with open(audio_path, 'rb') as audio_file:
        audio_bytes = audio_file.read()
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')

    # Prepare the request payload
    url = 'http://localhost:8000/transcribe'
    headers = {'Content-Type': 'application/json'}
    data = {
        'audio': audio_base64,
        'model': 'base',
        'language': 'auto'
    }

    # Send the request
    try:
        response = requests.post(url, headers=headers, json=data)
        print(f"Status Code: {response.status_code}")
        if response.status_code == 200:
            print("Response:")
            print(response.json())
        else:
            print("Error Response:")
            print(response.text)
    except Exception as e:
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 test_fastwhisper.py <audio_file_path>")
        sys.exit(1)
    transcribe_audio(sys.argv[1])
