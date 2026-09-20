import json, os, urllib.request, boto3

bedrock = boto3.client("bedrock-runtime")
polly = boto3.client("polly")
s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
lessons_table = dynamodb.Table(os.environ["LESSONS_TABLE"])
PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]
MODEL_ID = os.environ["BEDROCK_TEXT_MODEL_ID"]

PROMPT_TEMPLATE = """You are an expert educational translator. I will provide a JSON object containing study notes. 
Translate ALL the textual content (overview, topics, notes, chapter titles/texts, flashcard questions/answers) into {target_language}.
You MUST return the exact same STRICT JSON structure, just translated. DO NOT wrap the JSON in markdown blocks (e.g. ```json).

Original JSON:
{source_json}
"""

def handler(event, context):
    body = json.loads(event["body"])
    course_pk = body["coursePK"]
    lesson_sk = body["lessonSK"]
    target_lang = body["targetLanguage"] # e.g. "Spanish"
    polly_voice = body.get("pollyVoiceId", "Lupe") # e.g. "Lupe" for es-US

    # 1. Fetch original notes
    resp = lessons_table.get_item(Key={"PK": course_pk, "SK": lesson_sk})
    item = resp.get("Item")
    if not item or not item.get("notesS3Key"):
        return {"statusCode": 404, "body": json.dumps({"error": "Original notes not found"})}
        
    original_notes_key = item["notesS3Key"]
    s3_resp = s3.get_object(Bucket=PROCESSED_BUCKET, Key=original_notes_key)
    source_json = s3_resp["Body"].read().decode("utf-8")

    # 2. Bedrock Translation
    prompt = PROMPT_TEMPLATE.format(target_language=target_lang, source_json=source_json)
    
    GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")
    try:
        response = bedrock.converse(
            modelId=MODEL_ID,
            messages=[{"role": "user", "content": [{"text": prompt}]}],
            inferenceConfig={"maxTokens": 4096}
        )
        translated_text = response["output"]["message"]["content"][0]["text"]
    except Exception as e:
        print(f"Bedrock translation failed: {e}. Falling back to Groq...")
        if not GROQ_API_KEY or GROQ_API_KEY == "PASTE_YOUR_GROQ_API_KEY_HERE":
            return {"statusCode": 500, "body": json.dumps({"error": f"Bedrock failed and no Groq key: {e}"})}
            
        req = urllib.request.Request(
            "https://api.groq.com/openai/v1/chat/completions",
            data=json.dumps({
                "model": "qwen/qwen3.8-27b",
                "messages": [{"role": "user", "content": prompt}], "max_tokens": 4096
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
                translated_text = result["choices"][0]["message"]["content"]
                break
            except HTTPError as he:
                body = he.read().decode("utf-8", errors="replace")
                if he.code in (429, 500, 502, 503) and attempt < 2:
                    wait = 5 * (attempt + 1)
                    print(f"Groq HTTP {he.code}, retrying in {wait}s...")
                    time.sleep(wait)
                    last_error = f"HTTP {he.code} - {body}"
                    continue
                return {"statusCode": 500, "body": json.dumps({"error": f"Bedrock failed ({e}) & Groq failed: HTTP {he.code} - {body}"})}
            except URLError as ue:
                if attempt < 2:
                    time.sleep(5)
                    last_error = str(ue)
                    continue
                return {"statusCode": 500, "body": json.dumps({"error": f"Bedrock failed ({e}) & Groq failed: {ue}"})}
        else:
            return {"statusCode": 500, "body": json.dumps({"error": f"Bedrock failed ({e}) & Groq failed after retries: {last_error}"})}
    
    # Strip markdown wrappers if Bedrock added them
    translated_text = translated_text.strip()
    if translated_text.startswith("```json"): translated_text = translated_text[7:]
    elif translated_text.startswith("```"): translated_text = translated_text[3:]
    if translated_text.endswith("```"): translated_text = translated_text[:-3]
    translated_text = translated_text.strip()
    
    # 3. Parse translated JSON to get the overview for Polly
    try:
        translated_json = json.loads(translated_text)
        overview_text = translated_json.get("overview", "")
    except Exception as e:
        overview_text = "Translation failed to parse."

    # 4. Amazon Polly Synthesis
    audio_key = None
    if overview_text:
        try:
            polly_resp = polly.synthesize_speech(
                Text=overview_text,
                OutputFormat="mp3",
                VoiceId=polly_voice,
                Engine="neural"
            )
            if "AudioStream" in polly_resp:
                lesson_id = lesson_sk.split("#")[1]
                course_id = course_pk.split("#")[1]
                audio_key = f"{course_id}/{lesson_id}/recap_{target_lang}.mp3"
                s3.put_object(Bucket=PROCESSED_BUCKET, Key=audio_key, Body=polly_resp["AudioStream"].read())
        except Exception as e:
            print(f"Polly failed: {e}")

    # 5. Save translated JSON to S3
    lesson_id = lesson_sk.split("#")[1]
    course_id = course_pk.split("#")[1]
    translated_notes_key = f"{course_id}/{lesson_id}/notes_{target_lang}.md"
    s3.put_object(Bucket=PROCESSED_BUCKET, Key=translated_notes_key, Body=translated_text.encode("utf-8"))

    # 6. Update DynamoDB
    lessons_table.update_item(
        Key={"PK": course_pk, "SK": lesson_sk},
        UpdateExpression="SET translatedNotesS3Key = :n, translatedAudioS3Key = :a, targetLanguage = :l",
        ExpressionAttributeValues={
            ":n": translated_notes_key,
            ":a": audio_key or "",
            ":l": target_lang
        }
    )

    audio_presigned_url = None
    if audio_key:
        audio_presigned_url = s3.generate_presigned_url(
            ClientMethod="get_object",
            Params={"Bucket": PROCESSED_BUCKET, "Key": audio_key},
            ExpiresIn=3600
        )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "translatedNotesText": translated_text,
            "translatedAudioUrl": audio_presigned_url,
            "targetLanguage": target_lang
        })
    }
