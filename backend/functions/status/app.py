import json, os, boto3

dynamodb = boto3.resource("dynamodb")
s3 = boto3.client("s3")
lessons_table = dynamodb.Table(os.environ["LESSONS_TABLE"])
PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]

def handler(event, context):
    lesson_id = event["pathParameters"]["lessonId"]
    course_pk = event["queryStringParameters"]["coursePK"]  # e.g. COURSE#abc123
    resp = lessons_table.get_item(Key={"PK": course_pk, "SK": f"LESSON#{lesson_id}"}, ConsistentRead=True)
    item = resp.get("Item")
    if not item:
        return {"statusCode": 404, "body": json.dumps({"error": "not found"})}
        
    notes_text = None
    notes_key = item.get("notesS3Key")
    if notes_key:
        try:
            s3_resp = s3.get_object(Bucket=PROCESSED_BUCKET, Key=notes_key)
            notes_text = s3_resp["Body"].read().decode("utf-8")
        except Exception as e:
            notes_text = f"S3_ERROR: {str(e)} (Bucket: {PROCESSED_BUCKET}, Key: {notes_key})"

    return {
        "statusCode": 200,
        "body": json.dumps({
            "lessonId": lesson_id,
            "status": item.get("status", "PROCESSING"),
            "progress": int(item.get("progress", 0)),
            "notesS3Key": notes_key,
            "narrationS3Key": item.get("narrationS3Key"),
            "notesText": notes_text,
            "errorMessage": item.get("errorMessage")
        }),
    }