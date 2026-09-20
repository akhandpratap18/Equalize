import json, os, uuid, time, boto3

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")
lessons_table = dynamodb.Table(os.environ["LESSONS_TABLE"])
RAW_BUCKET = os.environ["RAW_BUCKET"]

def handler(event, context):
    body = json.loads(event["body"])
    course_id = body["courseId"]
    lesson_id = body["lessonId"]
    title = body["title"]
    source_type = body["sourceType"]  # LIVE_CAPTURE | IMPORTED_AUDIO | IMPORTED_VIDEO
    file_extension = body["fileExtension"]  # e.g. "m4a", "mp4"
    raw_key = f"{course_id}/{lesson_id}/raw.{file_extension}"

    lessons_table.put_item(Item={
        "PK": f"COURSE#{course_id}",
        "SK": f"LESSON#{lesson_id}",
        "GSI1PK": f"USER#{body['userId']}",
        "GSI1SK": f"LESSON#{lesson_id}",
        "title": title,
        "sourceType": source_type,
        "status": "UPLOADING",
        "rawS3Key": raw_key,
        "createdAt": int(time.time() * 1000),
    })

    upload_url = s3.generate_presigned_url(
        ClientMethod="put_object",
        Params={"Bucket": RAW_BUCKET, "Key": raw_key},
        ExpiresIn=900,  # 15 minutes to complete the upload
    )

    return {
        "statusCode": 200,
        "body": json.dumps({
            "lessonId": lesson_id,
            "uploadUrl": upload_url,
            "rawS3Key": raw_key,
        }),
    }