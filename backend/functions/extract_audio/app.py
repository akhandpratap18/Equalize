import json, os, boto3

s3 = boto3.client("s3")
RAW_BUCKET = os.environ["RAW_BUCKET"]

def handler(event, context):
    raw_key = event["rawS3Key"]
    
    # Preserve the original file extension (e.g. .caf, .m4a)
    ext = raw_key.rsplit(".", 1)[-1] if "." in raw_key else "m4a"
    base = raw_key.rsplit(".", 1)[0]
    audio_key = f"{base}_audio.{ext}"
    
    s3.copy_object(
        Bucket=RAW_BUCKET,
        CopySource={"Bucket": RAW_BUCKET, "Key": raw_key},
        Key=audio_key
    )

    event["audioS3Key"] = audio_key
    return event
