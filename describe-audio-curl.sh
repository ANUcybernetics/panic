#!/bin/bash


AUDIO_FILE=$1
if [ -z "$AUDIO_FILE" ]; then
    echo "Error: Audio file path must be provided"
    exit 1
fi

AUDIO_DATA=$(ffmpeg -v quiet -i $AUDIO_FILE -f mp3 - | base64 | tr -d '\n')
MODEL="gemini-1.5-flash"

curl -s -X POST \
     -H "x-goog-api-key: ${VERTEX_API_TOKEN}" \
     -H "Content-Type: application/json; charset=utf-8" \
     -d "{
       \"contents\": {
         \"role\": \"USER\",
         \"parts\": [
           {
             \"inline_data\": {
               \"data\": \"${AUDIO_DATA}\",
               \"mime_type\": \"audio/mp3\"
             }
           },
           {
             \"text\": \"Describe the audio file in two sentences. If it contains speech, please transcribe and return only the transcription. If it is instrumental music or sfx, describe what you hear.\"
           }
         ]
       }
     }" \
     "https://generativelanguage.googleapis.com/v1/models/${MODEL}:generateContent" | \
     jq -r '.candidates[0].content.parts[0].text'
