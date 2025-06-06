import requests
import base64
import json

def test_transcribe():
    # Read the audio file
    with open('test_resources/test.aac', 'rb') as audio_file:
        audio_bytes = audio_file.read()
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')

    url = 'http://localhost:8000/transcribe'
    headers = {'Content-Type': 'application/json'}
    data = {
        'audio': audio_base64,
        'model': 'base',
        'language': 'auto'
    }

    try:
        response = requests.post(url, headers=headers, data=json.dumps(data))
        print(f"Status Code: {response.status_code}")
        if response.status_code == 200:
            print("Response:")
            print(json.dumps(response.json(), indent=2))
        else:
            print("Error Response:")
            print(response.text)
    except Exception as e:
        print(f"Error: {str(e)}")

if __name__ == "__main__":
    test_transcribe() 