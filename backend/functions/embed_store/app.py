import json, os, decimal, urllib.request, urllib.error, boto3

bedrock = boto3.client("bedrock-runtime")
dynamodb = boto3.resource("dynamodb")
chunks_table = dynamodb.Table(os.environ["CHUNKS_TABLE"])
EMBED_MODEL_ID = os.environ["BEDROCK_EMBED_MODEL_ID"]
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")

def to_decimal_list(floats):
    return [decimal.Decimal(str(f)) for f in floats]

def handler(event, context):
    chunk = event["chunk"]
    lesson_id = event["lessonId"]
    course_id = event["courseId"]
    chunk_index = event["chunkIndex"]

    try:
        response = bedrock.invoke_model(modelId=EMBED_MODEL_ID, body=json.dumps({"inputText": chunk["text"]}))
        result = json.loads(response["body"].read())
        embedding = result["embedding"]
        provider = "bedrock"
    except Exception as bedrock_err:
        print(f"Bedrock embed failed: {bedrock_err}. Falling back to OpenAI...")
        if not OPENAI_API_KEY or OPENAI_API_KEY == "PASTE_YOUR_OPENAI_API_KEY_HERE":
            print(f"No OpenAI key configured. Falling back to mock embeddings.")
            embedding = [0.0] * 1536
            provider = "mock"
        else:
            req = urllib.request.Request(
                "https://api.openai.com/v1/embeddings",
                data=json.dumps({"model": "text-embedding-3-small", "input": chunk["text"]}).encode("utf-8"),
                headers={
                    "Content-Type": "application/json", 
                    "Authorization": f"Bearer {OPENAI_API_KEY}",
                    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
                }
            )
            import time
            last_error = None
            for attempt in range(3):
                try:
                    resp = urllib.request.urlopen(req, timeout=15)
                    result = json.loads(resp.read().decode("utf-8"))
                    embedding = result["data"][0]["embedding"]
                    provider = "openai"
                    break
                except urllib.error.HTTPError as he:
                    body = he.read().decode("utf-8", errors="replace")
                    if he.code in (429, 500, 502, 503) and attempt < 2:
                        wait = 5 * (attempt + 1)
                        print(f"OpenAI HTTP {he.code}, retrying in {wait}s (attempt {attempt + 1}/3)...")
                        time.sleep(wait)
                        last_error = f"HTTP {he.code} — {body}"
                        continue
                    print(f"OpenAI fallback failed: HTTP {he.code} — {body}. Using mock embeddings.")
                    embedding = [0.0] * 1536
                    provider = "mock"
                    break
                except urllib.error.URLError as ue:
                    if attempt < 2:
                        print(f"OpenAI network error, retrying: {ue}")
                        time.sleep(5)
                        last_error = str(ue)
                        continue
                    print(f"OpenAI fallback network error: {ue}. Using mock embeddings.")
                    embedding = [0.0] * 1536
                    provider = "mock"
                    break
            else:
                print(f"OpenAI fallback exhausted retries: {last_error}. Using mock embeddings.")
                embedding = [0.0] * 1536
                provider = "mock"

    chunks_table.put_item(Item={
        "PK": f"LESSON#{lesson_id}",
        "SK": f"CHUNK#{chunk_index:04d}",
        "GSI1PK": f"COURSE#{course_id}",
        "text": chunk["text"],
        "embedding": to_decimal_list(embedding),
        "embeddingProvider": provider,
        "startTimeSec": decimal.Decimal(str(chunk["startTimeSec"])),
        "endTimeSec": decimal.Decimal(str(chunk["endTimeSec"])),
        "sourceType": chunk["sourceType"],
    })
    return {"status": "stored", "chunkIndex": chunk_index}
