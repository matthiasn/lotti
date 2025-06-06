import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from faster_whisper import WhisperModel
import uvicorn
import base64
import json
import tempfile
from typing import List, Optional

app = FastAPI()

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allows all origins
    allow_credentials=True,
    allow_methods=["*"],  # Allows all methods
    allow_headers=["*"],  # Allows all headers
)

# Initialize the model
model = WhisperModel("base")

class TranscriptionSegment:
    def __init__(self, id: int, start: float, end: float, text: str):
        self.id = id
        self.start = start
        self.end = end
        self.text = text

    def to_dict(self):
        return {
            "id": self.id,
            "start": self.start,
            "end": self.end,
            "text": self.text
        }

class TranscribeRequest(BaseModel):
    audio: str
    model: str = "base"
    language: str = "auto"

@app.post("/transcribe")
async def transcribe(request: TranscribeRequest):
    try:
        # Decode base64 audio
        audio_bytes = base64.b64decode(request.audio)
        # Save to a temporary file
        with tempfile.NamedTemporaryFile(delete=False, suffix='.m4a') as temp_file:
            temp_file.write(audio_bytes)
            temp_file_path = temp_file.name

        # Transcribe
        segments, info = model.transcribe(
            temp_file_path,
            language=request.language if request.language != "auto" else None,
            beam_size=5
        )
        # Convert segments to list of dictionaries
        segments_list = []
        for i, segment in enumerate(segments):
            segments_list.append(
                TranscriptionSegment(
                    id=i,
                    start=segment.start,
                    end=segment.end,
                    text=segment.text
                ).to_dict()
            )
        # Prepare response
        response = {
            "text": " ".join([seg["text"] for seg in segments_list]),
            "language": info.language,
            "segments": segments_list
        }
        # Clean up the temporary file
        os.unlink(temp_file_path)
        return response
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/transcribe/chat/completions")
async def transcribe_chat_completions(request: TranscribeRequest):
    return await transcribe(request)

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000) 