import json, os, decimal, math, urllib.request, urllib.error, boto3

bedrock = boto3.client("bedrock-runtime")
dynamodb = boto3.resource("dynamodb")
chunks_table = dynamodb.Table(os.environ["CHUNKS_TABLE"])
EMBED_MODEL_ID = os.environ["BEDROCK_EMBED_MODEL_ID"]
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY", "")

def cosine_similarity(a, b):
    if len(a) != len(b):
        return -1.0   # mismatched-dimension vectors are never a valid match
    dot = sum(x * y for x, y in zip(a, b))
    norm_a = math.sqrt(sum(x * x for x in a))
    norm_b = math.sqrt(sum(y * y for y in b))
    if norm_a == 0 or norm_b == 0:
        return 0.0
    return dot / (norm_a * norm_b)

def embed_text(text):
    """Bedrock Titan first, OpenAI fallback. Never lets a bare urllib exception escape uncaught."""
    try:
        response = bedrock.invoke_model(modelId=EMBED_MODEL_ID, body=json.dumps({"inputText": text}))
        return json.loads(response["body"].read())["embedding"], "bedrock"
    except Exception as bedrock_err:
        print(f"Bedrock embed failed: {bedrock_err}. Falling back to OpenAI...")
        if not OPENAI_API_KEY or OPENAI_API_KEY == "PASTE_YOUR_OPENAI_API_KEY_HERE":
            raise RuntimeError(f"Bedrock embed failed and no OpenAI key configured: {bedrock_err}") from bedrock_err
        req = urllib.request.Request(
            "https://api.openai.com/v1/embeddings",
            data=json.dumps({"model": "text-embedding-3-small", "input": text}).encode("utf-8"),
            headers={
                "Content-Type": "application/json", 
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
            }
        )
        try:
            resp = urllib.request.urlopen(req, timeout=15)
            result = json.loads(resp.read().decode("utf-8"))
            return result["data"][0]["embedding"], "openai"
        except urllib.error.HTTPError as he:
            body = he.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"Bedrock embed failed ({bedrock_err}); OpenAI fallback also failed: HTTP {he.code} — {body}") from he
        except urllib.error.URLError as ue:
            raise RuntimeError(f"Bedrock embed failed ({bedrock_err}); OpenAI fallback network error: {ue}") from ue

def handler(event, context):
    try:
        body = json.loads(event["body"])
        question = body["question"]
        scope = body["scope"]  # "lesson" | "course"

        query_vector, query_provider = embed_text(question)

        if scope == "lesson":
            resp = chunks_table.query(
                KeyConditionExpression="PK = :pk",
                ExpressionAttributeValues={":pk": f"LESSON#{body['lessonId']}"},
            )
        else:
            resp = chunks_table.query(
                IndexName="GSI1",
                KeyConditionExpression="GSI1PK = :pk",
                ExpressionAttributeValues={":pk": f"COURSE#{body['courseId']}"},
            )
        candidates = resp.get("Items", [])

        scored = []
        for item in candidates:
            # Chunks written before "embeddingProvider" existed default to "bedrock",
            # the original assumption.
            item_provider = item.get("embeddingProvider", "bedrock")
            if item_provider != query_provider:
                continue
            embedding = [float(x) for x in item["embedding"]]
            score = cosine_similarity(query_vector, embedding)
            if score > 0:
                scored.append((score, item))
        scored.sort(key=lambda x: x[0], reverse=True)
        top = scored[:5]

        citations = [
            {
                "lessonId": item["PK"].split("#")[1],
                "startTimeSec": float(item["startTimeSec"]),
                "text": item["text"],
                "textPreview": item["text"][:120],
            }
            for score, item in top
        ]

        return {"statusCode": 200, "body": json.dumps({"citations": citations, "matchCount": len(citations)})}

    except Exception as e:
        # This feeds directly into a live chat UI — never hard-fail with a bare 500.
        print(f"rag_query failed: {e}")
        return {"statusCode": 200, "body": json.dumps({"citations": [], "matchCount": 0, "error": str(e)})}
