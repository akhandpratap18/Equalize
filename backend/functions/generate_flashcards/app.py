import json
import os
import urllib.request
import boto3
import traceback
import re

bedrock = boto3.client("bedrock-runtime")
s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
lessons_table = dynamodb.Table(os.environ["LESSONS_TABLE"])
PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]
MODEL_ID = os.environ["BEDROCK_TEXT_MODEL_ID"]

PROMPT_TEMPLATE = """You are an expert educator creating a multiple-choice quiz for active recall study. 
I will provide you with the study notes and overview of a lecture.
Create 5-7 high-quality multiple-choice questions testing the key concepts.
Output a STRICT JSON array (no markdown wrappers) with this exact structure:
[
  {{
    "question": "A concise question testing a key concept.",
    "options": ["Option A", "Option B", "Option C", "Option D"],
    "correctAnswer": 2
  }}
]
Note: correctAnswer is the 0-based index of the correct option in the options array.

Notes:
{notes_text}
"""

def handler(event, context):
    try:
        body = json.loads(event.get("body", "{}"))
        course_pk = body.get("coursePK")
        lesson_sk = body.get("lessonSK")
        
        if not course_pk or not lesson_sk:
            return {"statusCode": 400, "body": json.dumps({"error": "Missing coursePK or lessonSK"})}

        resp = lessons_table.get_item(Key={"PK": course_pk, "SK": lesson_sk})
        item = resp.get("Item")
        if not item or not item.get("notesS3Key"):
            return {"statusCode": 404, "body": json.dumps({"error": "Notes not found"})}
            
        notes_key = item["notesS3Key"]
        
        try:
            s3_resp = s3.get_object(Bucket=PROCESSED_BUCKET, Key=notes_key)
            existing_json_str = s3_resp["Body"].read().decode("utf-8")
            existing_json = json.loads(existing_json_str)
        except Exception as e:
            return {"statusCode": 500, "body": json.dumps({"error": f"Failed to read/parse existing notes: {str(e)}"})}

        notes_content = f"Overview: {existing_json.get('overview', '')}\n\nNotes:\n{existing_json.get('notes', '')}"
        
        # This format string was crashing because of the single { } in the prompt! 
        prompt = PROMPT_TEMPLATE.format(notes_text=notes_content)

        GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")
        flashcards_text = ""
        
        try:
            response = bedrock.converse(
                modelId=MODEL_ID,
                messages=[{"role": "user", "content": [{"text": prompt}]}],
                inferenceConfig={"maxTokens": 4096}
            )
            flashcards_text = response["output"]["message"]["content"][0]["text"]
        except Exception as e:
            print(f"Bedrock failed: {e}. Falling back to Groq...")
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
                    groq_resp = urllib.request.urlopen(req, timeout=30)
                    result = json.loads(groq_resp.read().decode("utf-8"))
                    flashcards_text = result["choices"][0]["message"]["content"]
                    break
                except HTTPError as he:
                    err_body = he.read().decode("utf-8", errors="replace")
                    if he.code in (429, 500, 502, 503) and attempt < 2:
                        wait = 5 * (attempt + 1)
                        time.sleep(wait)
                        last_error = f"HTTP {he.code} - {err_body}"
                        continue
                    return {"statusCode": 500, "body": json.dumps({"error": f"Bedrock failed ({e}) & Groq failed: HTTP {he.code} - {err_body}"})}
                except URLError as ue:
                    if attempt < 2:
                        time.sleep(5)
                        last_error = str(ue)
                        continue
                    return {"statusCode": 500, "body": json.dumps({"error": f"Bedrock failed ({e}) & Groq failed: {ue}"})}
            else:
                return {"statusCode": 500, "body": json.dumps({"error": f"Bedrock failed ({e}) & Groq failed after retries: {last_error}"})}
        
        flashcards_text = flashcards_text.strip()
        if flashcards_text.startswith("```json"): flashcards_text = flashcards_text[7:]
        elif flashcards_text.startswith("```"): flashcards_text = flashcards_text[3:]
        if flashcards_text.endswith("```"): flashcards_text = flashcards_text[:-3]
        flashcards_text = flashcards_text.strip()
        
        try:
            flashcards_array = json.loads(flashcards_text)
        except:
            arr_match = re.search(r'\[.*\]', flashcards_text, re.DOTALL)
            if arr_match:
                try:
                    flashcards_array = json.loads(arr_match.group(0))
                except:
                    flashcards_array = []
                    blocks = re.finditer(r'\{[^{}]*\}', flashcards_text)
                    for b in blocks:
                        try:
                            item = json.loads(b.group(0))
                            if "question" in item and "options" in item and "correctAnswer" in item:
                                flashcards_array.append(item)
                        except:
                            pass
            else:
                flashcards_array = []
                
        if not flashcards_array:
            return {"statusCode": 500, "body": json.dumps({"error": "Failed to parse flashcards array"})}
        
        existing_json["flashcards"] = flashcards_array
        s3.put_object(Bucket=PROCESSED_BUCKET, Key=notes_key, Body=json.dumps(existing_json).encode("utf-8"))
        
        return {
            "statusCode": 200,
            "body": json.dumps({"flashcards": flashcards_array})
        }
    except Exception as general_e:
        return {"statusCode": 500, "body": json.dumps({"error": str(general_e), "trace": traceback.format_exc()})}
