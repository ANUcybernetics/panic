#!/bin/bash

AUDIO_FILE="test-audio.ogg"
AUDIO_DATA=$(ffmpeg -v quiet -i $AUDIO_FILE -f mp3 - | base64 | tr -d '\n')
MODEL="gemini-1.5-flash"

echo "Audio data size: $(echo -n "$AUDIO_DATA" | wc -c | awk '{printf "%.2f", $1/1024}') kB"

curl -s "https://generativelanguage.googleapis.com/v1beta/models/$MODEL:generateContent?key=$GOOGLE_AI_STUDIO_TOKEN" \
    -H 'Content-Type: application/json' \
    -X POST \
    -d '{
      "contents": [{
        "parts":[
          {"text": "Describe this audio file in two sentences. If it contains speech, please transcribe and return only the transcription. If it is instrumental music or sound effects, describe what you hear."},
          {"inline_data":{"mime_type": "audio/ogg", "data": "'$AUDIO_DATA'"}}]
        }]
       }' | jq -r '.candidates[0].content.parts[0].text'
