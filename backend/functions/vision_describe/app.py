import json, os, base64, urllib.request, boto3

s3 = boto3.client("s3")
bedrock = boto3.client("bedrock-runtime")
RAW_BUCKET = os.environ["RAW_BUCKET"]
MODEL_ID = os.environ["BEDROCK_TEXT_MODEL_ID"]
GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")

PROMPT = (
    "Describe this lecture slide for a blind student. Read all visible text "
    "verbatim. Describe any diagrams, charts, or images in plain words. "
    "Read any equations aloud in words (e.g. 'x squared plus two x'). "
    "Keep it factual and complete, no filler commentary."
)

def handler(slide_key, context):
    obj = s3.get_object(Bucket=RAW_BUCKET, Key=slide_key)
    image_bytes = obj["Body"].read()

    try:
        response = bedrock.converse(
            modelId=MODEL_ID,
            messages=[{
                "role": "user",
                "content": [
                    {
                        "image": {
                            "format": "jpeg",
                            "source": {"bytes": image_bytes}
                        }
                    },
                    {"text": PROMPT}
                ]
            }]
        )
        description = response["output"]["message"]["content"][0]["text"]
    except Exception as e:
        bedrock_error = str(e)
        print(f"Bedrock failed: {bedrock_error}. Falling back to Groq...")
        if not GROQ_API_KEY or GROQ_API_KEY == "PASTE_YOUR_GROQ_API_KEY_HERE":
            raise RuntimeError(f"Bedrock failed and no Groq key configured: {bedrock_error}") from e

        image_b64 = base64.b64encode(image_bytes).decode("utf-8")
        req = urllib.request.Request(
            "https://api.groq.com/openai/v1/chat/completions",
            data=json.dumps({
                "model": "qwen/qwen3.8-27b",
                "max_tokens": 900, "messages": [{
                    "role": "user",
                    "content": [
                        {"type": "text", "text": PROMPT},
                        {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"}}
                    ]
                }]
            }).encode("utf-8"),
            headers={
                "Content-Type": "application/json", 
                "Authorization": f"Bearer {GROQ_API_KEY}",
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
            }
        )

        import time
        from urllib.error import HTTPError, URLError

        last_error = None
        for attempt in range(3):
            try:
                response = urllib.request.urlopen(req, timeout=20)
                result = json.loads(response.read().decode("utf-8"))
                description = result["choices"][0]["message"]["content"]
                break
            except HTTPError as he:
                body = he.read().decode("utf-8", errors="replace")
                if he.code in (429, 500, 502, 503) and attempt < 2:
                    wait = 5 * (attempt + 1)
                    print(f"Groq HTTP {he.code}, retrying in {wait}s (attempt {attempt + 1}/3)...")
                    time.sleep(wait)
                    last_error = f"HTTP {he.code} — {body}"
                    continue
                raise RuntimeError(f"Bedrock failed ({bedrock_error}); Groq fallback failed: HTTP {he.code} — {body}") from he
            except URLError as ue:
                if attempt < 2:
                    print(f"Groq network error, retrying: {ue}")
                    time.sleep(5)
                    last_error = str(ue)
                    continue
                raise RuntimeError(f"Bedrock failed ({bedrock_error}); Groq fallback network error: {ue}") from ue
        else:
            raise RuntimeError(f"Bedrock failed ({bedrock_error}); Groq fallback exhausted retries: {last_error}")

    return {"slidePhotoKey": slide_key, "description": description}
