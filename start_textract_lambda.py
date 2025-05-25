# Lambda 1 (start_textract_lambda): Triggered by S3 upload. Starts Textract job with SNS notification.
# Lambda 2 (process_textract_result_lambda): Triggered by SNS, fetches the Textract job results and logs extracted text.


import boto3
import json
import logging

logger = logging.getLogger()
textract = boto3.client("textract", region_name="ap-south-1")


def lambda_handler(event, context):
    print("Recieved JSON", json.dumps(event))

    # Extract bucket and file name
    bucket = event["Records"][0]["s3"]["bucket"]["name"]
    document_key = event["Records"][0]["s3"]["object"]["key"]
    print(f"Bucket: {bucket}, Key: {document_key}")

    # Start Textract analysis job
    response = textract.start_document_analysis(
        DocumentLocation={
            "S3Object": {
                "Bucket": bucket,
                "Name": document_key,
            }
        },
        FeatureTypes=["TABLES", "FORMS"],
        NotificationChannel={
            "RoleArn": "arn:aws:iam::080636249926:role/TextractServiceNewRole",
            "SNSTopicArn": "arn:aws:sns:ap-south-1:080636249926:process-textract",
        },
    )
    print("Textract response", response)
    statusCode = response["ResponseMetadata"]["HTTPStatusCode"]
    job_id = response["JobId"]
    print(f"Started Textract job with ID: {job_id}")

    return {
        "statusCode": statusCode,
        "job_id": job_id,
        "body": json.dumps(f"Started Textract job: {job_id}"),
        "document_key": document_key,
    }
