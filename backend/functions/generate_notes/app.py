import json, os, urllib.request, boto3, time, re

bedrock = boto3.client("bedrock-runtime")
s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
lessons_table = dynamodb.Table(os.environ["LESSONS_TABLE"])
PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]
MODEL_ID = os.environ["BEDROCK_TEXT_MODEL_ID"]
GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")

PROMPT_TEMPLATE = """You are a study assistant. Analyze this section of a lecture transcript and output the following sections EXACTLY as shown below using XML tags. DO NOT use attributes in the XML tags.

<overview>
A brief 2 sentence summary of THIS SECTION.
</overview>

<topics>
Comma, Separated, List, Of, Topics
</topics>

<notes>
Detailed study notes for this section in Markdown format. Use headers (##), bold terms, and bullet points.
</notes>

<chapters>
<chapter>
<timestamp>00:00</timestamp>
<title>Section Title</title>
<description>A brief 1-2 sentence description giving a jist of what the speaker talked about in this section.</description>
</chapter>
<chapter>
<timestamp>01:30</timestamp>
<title>Next Section</title>
<description>...</description>
</chapter>
</chapters>

Group the transcript segments into logical chapters. Calculate the timestamp as MM:SS based on the startTimeSec of the first segment in the chapter (e.g., '00:00'). 
DO NOT INCLUDE THE TRANSCRIPT TEXT IN YOUR OUTPUT.

Packet:
{packet_json}
"""

def generate_notes_for_batch(batch):
    prompt = PROMPT_TEMPLATE.format(packet_json=json.dumps(batch))
    
    try:
        response = bedrock.converse(
            modelId=MODEL_ID,
            messages=[{"role": "user", "content": [{"text": prompt}]}],
            inferenceConfig={"maxTokens": 4096}
        )
        return response["output"]["message"]["content"][0]["text"]
    except Exception as e:
        bedrock_error = str(e)
        if not GROQ_API_KEY or GROQ_API_KEY == "PASTE_YOUR_GROQ_API_KEY_HERE":
            raise RuntimeError(f"Bedrock failed and no Groq key configured: {bedrock_error}") from e

        req = urllib.request.Request(
            "https://api.groq.com/openai/v1/chat/completions",
            data=json.dumps({
                "model": "qwen/qwen3.8-27b",
                "messages": [{"role": "user", "content": prompt}], "max_tokens": 1000
            }).encode("utf-8"),
            headers={
                "Content-Type": "application/json", 
                "Authorization": f"Bearer {GROQ_API_KEY}",
                "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
            }
        )

        from urllib.error import HTTPError, URLError

        last_error = None
        for attempt in range(4):
            try:
                response = urllib.request.urlopen(req, timeout=30)
                result = json.loads(response.read().decode("utf-8"))
                return result["choices"][0]["message"]["content"]
            except HTTPError as he:
                body = he.read().decode("utf-8", errors="replace")
                if he.code in (429, 500, 502, 503) and attempt < 3:
                    wait = 35 if he.code == 429 else 5 * (attempt + 1)
                    print(f"Groq HTTP {he.code}, retrying in {wait}s...")
                    time.sleep(wait)
                    last_error = f"HTTP {he.code} — {body}"
                    continue
                raise RuntimeError(f"Bedrock failed ({bedrock_error}); Groq fallback failed: HTTP {he.code} — {body}") from he
            except URLError as ue:
                if attempt < 3:
                    print(f"Groq network error, retrying: {ue}")
                    time.sleep(5)
                    last_error = str(ue)
                    continue
                raise RuntimeError(f"Bedrock failed ({bedrock_error}); Groq fallback network error: {ue}") from ue
        else:
            raise RuntimeError(f"Bedrock failed ({bedrock_error}); Groq fallback exhausted retries: {last_error}")

def extract_tags(text, tag):
    match = re.search(f"<{tag}>(.*?)</{tag}>", text, re.DOTALL | re.IGNORECASE)
    return match.group(1).strip() if match else ""

def timestamp_to_seconds(ts):
    parts = ts.split(':')
    if len(parts) == 2:
        try:
            return int(parts[0]) * 60 + int(parts[1])
        except:
            return 0
    elif len(parts) == 3:
        try:
            return int(parts[0]) * 3600 + int(parts[1]) * 60 + int(parts[2])
        except:
            return 0
    return 0

def format_timestamp(seconds):
    m = seconds // 60
    s = seconds % 60
    return f"{m:02d}:{s:02d}"

def parse_llm_output(text, original_batch):
    chapters = []
    chapter_blocks = re.finditer(r'<chapter>(.*?)</chapter>', text, re.DOTALL | re.IGNORECASE)
    for block in chapter_blocks:
        chapter_content = block.group(1)
        ts = extract_tags(chapter_content, "timestamp")
        title = extract_tags(chapter_content, "title")
        desc = extract_tags(chapter_content, "description")
        
        if ts and title:
            chapters.append({
                "timestamp": ts,
                "seconds": timestamp_to_seconds(ts),
                "title": title,
                "description": desc,
                "text": ""
            })
            
    # Sort chapters by timestamp just in case
    chapters.sort(key=lambda x: x["seconds"])
    
    # Weave text from original batch into chapters
    if not chapters:
        # If LLM failed to generate chapters, put everything in one chapter
        if original_batch:
            start_sec = original_batch[0].get("startTimeSec", 0)
            full_text = " ".join([seg.get("text", "") for seg in original_batch])
            chapters.append({
                "timestamp": format_timestamp(start_sec),
                "title": "Transcript Segment",
                "description": "",
                "text": full_text
            })
    else:
        for i, chapter in enumerate(chapters):
            start_sec = chapter["seconds"]
            # If it's the last chapter, it takes everything until the end of the batch
            # Otherwise it takes up to the next chapter's start
            end_sec = chapters[i+1]["seconds"] if i < len(chapters) - 1 else float('inf')
            
            # Find segments in this window
            chapter_text = []
            for seg in original_batch:
                seg_time = seg.get("startTimeSec", 0)
                if start_sec <= seg_time < end_sec:
                    chapter_text.append(seg.get("text", ""))
                    
            # If no segments fell strictly in this window (e.g. LLM hallucinates timestamp),
            # just append nothing or handle edge cases.
            chapter["text"] = " ".join(chapter_text).strip()
            
            # Delete the temporary 'seconds' key
            del chapter["seconds"]
        
    return {
        "overview": extract_tags(text, "overview"),
        "topics": extract_tags(text, "topics"),
        "notes": extract_tags(text, "notes"),
        "chapters": chapters
    }

def handler(event, context):
    batches = event.get("noteBatches", [])
    if not batches:
        batches = [event.get("packet", [])]
        
    final_overview = []
    final_topics = set()
    final_notes = []
    final_chapters = []
    
    print(f"Processing {len(batches)} batches...")
    
    for i, batch in enumerate(batches):
        print(f"Generating notes for batch {i+1}/{len(batches)}...")
        
        if i > 0:
            print("Sleeping 32 seconds to respect Groq rate limits...")
            time.sleep(32)
            
        raw_output = generate_notes_for_batch(batch)
        print(f"LLM Raw Output Length: {len(raw_output)}")
        
        parsed = parse_llm_output(raw_output, batch)
        
        if parsed["overview"]: final_overview.append(parsed["overview"])
        if parsed["topics"]:
            topics_list = [t.strip() for t in parsed["topics"].split(",")]
            for t in topics_list:
                if t: final_topics.add(t)
        if parsed["notes"]: final_notes.append(parsed["notes"])
        if parsed["chapters"]: final_chapters.extend(parsed["chapters"])

    combined_topics = ", ".join(list(final_topics))
    combined_overview = " ".join(final_overview)
    combined_markdown = "\n\n---\n\n".join(final_notes)
    
    master_json = {
        "overview": combined_overview,
        "topics": combined_topics,
        "notes": combined_markdown,
        "chapters": final_chapters
    }
    
    notes_text = json.dumps(master_json)

    notes_key = f"{event['coursePK'].split('#')[1]}/{event['lessonId']}/notes.md"
    s3.put_object(Bucket=PROCESSED_BUCKET, Key=notes_key, Body=notes_text.encode("utf-8"))

    lessons_table.update_item(
        Key={"PK": event["coursePK"], "SK": event["lessonSK"]},
        UpdateExpression="SET notesS3Key = :k",
        ExpressionAttributeValues={":k": notes_key},
    )

    event["notesS3Key"] = notes_key
    return event
