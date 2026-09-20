import json, os, boto3

sfn = boto3.client("stepfunctions")
STATE_MACHINE_ARN = os.environ["STATE_MACHINE_ARN"]
dynamodb = boto3.resource("dynamodb")
lessons_table = dynamodb.Table(os.environ["LESSONS_TABLE"])

def handler(event, context):
    lesson_id = event["pathParameters"]["lessonId"]
    body = json.loads(event["body"])
    
    # Also update status to PROCESSING
    lessons_table.update_item(
        Key={"PK": body["coursePK"], "SK": f"LESSON#{lesson_id}"},
        UpdateExpression="SET #s = :val",
        ExpressionAttributeNames={"#s": "status"},
        ExpressionAttributeValues={":val": "PROCESSING"}
    )
    
    transcript_segments = []
    raw_transcript = body.get("rawTranscript", "")
    if raw_transcript.strip():
        transcript_segments.append({
            "text": raw_transcript,
            "startTimeSec": 0,
            "endTimeSec": 100, # Mock duration
            "sourceType": "SPOKEN"
        })
    
    sfn.start_execution(
        stateMachineArn=STATE_MACHINE_ARN,
        input=json.dumps({
            "lessonId": lesson_id,
            "coursePK": body["coursePK"],
            "lessonSK": f"LESSON#{lesson_id}",
            "sourceType": body["sourceType"],
            "rawS3Key": body["rawS3Key"],
            "slidePhotoKeys": body.get("slidePhotoKeys", []),
            "transcriptSegments": transcript_segments
        }),
    )
    return {"statusCode": 200, "body": json.dumps({"status": "PROCESSING_STARTED"})}
