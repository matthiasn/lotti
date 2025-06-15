from fastapi import File, Form, UploadFile
from fastapi.responses import StreamingResponse
from typing import Dict, Any, Optional, Union
import tempfile
import os
from fastapi import HTTPException
from fastapi.logger import logger

@app.post("/transcribe")
async def transcribe(
    file: UploadFile = File(...),
    model: str = Form("base"),
    stream: bool = Form(False),
    language: Optional[str] = Form(None),
    beam_size: int = Form(5),
    temperature: float = Form(0.0),
) -> Union[Dict[str, Any], StreamingResponse]:
    """Transcribe audio file using FastWhisper."""
    try:
        # Save uploaded file to temporary location
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as temp_file:
            content = await file.read()
            temp_file.write(content)
            temp_file_path = temp_file.name

        # Get model and batch size
        pipe, batch_size = get_model(model)

        # Set language if provided
        if language and language != "auto":
            pipe.language = language

        # Set beam size and temperature
        pipe.beam_size = beam_size
        pipe.temperature = temperature

        if stream:
            return StreamingResponse(
                stream_transcription(temp_file_path, pipe, batch_size),
                media_type="text/event-stream",
            )
        else:
            # Process the audio file
            result = pipe(
                temp_file_path,
                batch_size=batch_size,
                return_timestamps=True,
            )

            # Clean up temporary file
            os.unlink(temp_file_path)

            # Format the response
            return {
                "text": result.text,
                "segments": [
                    {
                        "text": segment.text,
                        "start": segment.start,
                        "end": segment.end,
                    }
                    for segment in result.segments
                ],
            }

    except Exception as e:
        logger.error(f"Error during transcription: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=500,
            detail="An error occurred during transcription",
        ) 