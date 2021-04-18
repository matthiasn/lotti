# Speech to text

In this app, I want to be able to take voice notes, with automated speech-to-text, with the option to choose between different speech recognition providers. After all, there likely won't be one that's best for all voices, so why not give the user (me at the moment) some options?

## AssemblyAI

Let's try this one first.

    curl --request POST \
    -v \
    --data-binary \
    --url https://api.assemblyai.com/v2/upload \
    --header 'authorization: YOUR-API-TOKEN' \
    -H "Transfer-Encoding: chunked" \
    -T /path/to/your/audio.wav

curl --request POST \
--url https://api.assemblyai.com/v2/transcript \
--header 'authorization: YOUR-API-TOKEN' \
--header 'content-type: application/json' \
--data '{"audio_url": "https://cdn.assemblyai.com/upload/ccbbbfaf-f319-4455-9556-272d48faaf7f"}'

curl --request POST \
--url https://api.assemblyai.com/v2/transcript \
--header 'authorization: YOUR-API-TOKEN' \
--header 'content-type: application/json' \
--data '{"audio_url": "https://app.assemblyai.com/static/media/phone_demo_clip_1.wav", "speaker_labels": true}'
