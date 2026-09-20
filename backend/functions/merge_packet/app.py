import urllib.request
import json
import boto3
import os

s3 = boto3.client("s3")

def transcribe_audio_groq(s3_key):
    try:
        RAW_BUCKET = os.environ["RAW_BUCKET"]
        GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")
        if not GROQ_API_KEY:
            return []
            
        print(f"Downloading {s3_key} from {RAW_BUCKET} for Whisper transcription")
        response = s3.get_object(Bucket=RAW_BUCKET, Key=s3_key)
        file_bytes = response['Body'].read()
        
        url = "https://api.groq.com/openai/v1/audio/transcriptions"
        boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
        
        body = bytearray()
        body.extend(f"--{boundary}\r\n".encode('utf-8'))
        body.extend(f"Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".encode('utf-8'))
        body.extend(f"Content-Type: audio/m4a\r\n\r\n".encode('utf-8'))
        body.extend(file_bytes)
        body.extend(b"\r\n")
        body.extend(f"--{boundary}\r\n".encode('utf-8'))
        body.extend(f"Content-Disposition: form-data; name=\"model\"\r\n\r\n".encode('utf-8'))
        body.extend(b"whisper-large-v3\r\n")
        body.extend(f"--{boundary}\r\n".encode('utf-8'))
        body.extend(f"Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".encode('utf-8'))
        body.extend(b"verbose_json\r\n")
        body.extend(f"--{boundary}--\r\n".encode('utf-8'))
        
        req = urllib.request.Request(url, data=bytes(body))
        req.add_header('Authorization', f'Bearer {GROQ_API_KEY}')
        req.add_header('Content-Type', f'multipart/form-data; boundary={boundary}')
        req.add_header('User-Agent', 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36')
        
        print("Sending to Groq Whisper API...")
        resp = urllib.request.urlopen(req)
        result = json.loads(resp.read().decode('utf-8'))
        
        segments = result.get('segments', [])
        formatted_segments = []
        for seg in segments:
            formatted_segments.append({
                "text": seg.get("text", "").strip(),
                "startTimeSec": int(seg.get("start", 0)),
                "endTimeSec": int(seg.get("end", 0)),
                "sourceType": "SPOKEN"
            })
        
        # Fallback if segments is empty but text exists
        if not formatted_segments and result.get("text"):
            formatted_segments.append({
                "text": result.get("text", "").strip(),
                "startTimeSec": 0,
                "endTimeSec": 100,
                "sourceType": "SPOKEN"
            })
            
        return formatted_segments
    except Exception as e:
        print(f"Groq Whisper transcription failed: {e}")
        return []

def handler(event, context):
    transcript_segments = event.get("transcriptSegments", [])
    slide_items = event.get("slideDescriptions", [])
    
    needs_backend_transcription = False
    if not transcript_segments:
        needs_backend_transcription = True
    elif "[System Error:" in transcript_segments[0].get("text", ""):
        needs_backend_transcription = True
        
    if needs_backend_transcription:
        raw_key = event.get("rawS3Key")
        if raw_key:
            backend_segments = transcribe_audio_groq(raw_key)
            if backend_segments:
                transcript_segments = backend_segments

    packet = []
    for seg in transcript_segments:
        packet.append({
            "text": seg["text"],
            "startTimeSec": seg["startTimeSec"],
            "endTimeSec": seg["endTimeSec"],
            "sourceType": "SPOKEN",
        })
    for slide in slide_items:
        packet.append({
            "text": slide["description"],
            "startTimeSec": slide.get("timestampSec", 0),
            "endTimeSec": slide.get("timestampSec", 0),
            "sourceType": "SLIDE_DESCRIPTION",
        })
    packet.sort(key=lambda x: x["startTimeSec"])

    event["packet"] = packet
    event["transcriptSegments"] = transcript_segments
    return event
