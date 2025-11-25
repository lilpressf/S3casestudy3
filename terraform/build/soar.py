import os
import json
import boto3
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

sns = boto3.client("sns")
dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["TABLE_NAME"])

def handler(event, context):
    logger.info(f"Received event: {json.dumps(event)}")

    # Loop through records 
    for record in event.get("Records", []) or [event]:
        try:
            detail_type = record.get("detail-type") or record.get("detail_type", "Unknown Event")
            source = record.get("source", "Unknown")
            detail = record.get("detail", {})

            message = format_alert(detail_type, source, detail)
            logger.info(f"Formatted message: {message}")

            sns.publish(
                TopicArn=os.environ["SNS_TOPIC_ARN"],
                Subject=f"[SOAR] Event received – {detail_type}",
                Message=message
            )

            table.put_item(Item={
                "pk": f"event#{context.aws_request_id}",
                "sk": detail_type,
                "source": source,
                "raw_event": json.dumps(record)
            })

        except Exception as e:
            logger.error(f"Error processing record: {e}")

    return {"statusCode": 200, "body": json.dumps({"msg": "Processed"})}


def format_alert(detail_type, source, detail):
    """Format a clean human-readable alert message."""

    # Handle Security Hub findings
    if source == "aws.securityhub":
        findings = detail.get("findings", [])
        if not findings:
            return f"[SecurityHub] No findings in event."

        f = findings[0]  # Take the first finding
        title = f.get("Title", "Unknown finding")
        severity = f.get("Severity", {}).get("Label", "UNKNOWN")
        region = f.get("Region", "Unknown")
        resource = f.get("Resources", [{}])[0].get("Id", "Unknown resource")
        remediation = f.get("Remediation", {}).get("Recommendation", {}).get("Url", "N/A")

        return (
            f"[SOAR Alert] Security Hub Finding\n"
            f"Severity: {severity}\n"
            f"Title: {title}\n"
            f"Region: {region}\n"
            f"Resource: {resource}\n"
            f"Remediation: {remediation}\n"
        )

    # Handle GuardDuty findings
    elif source == "aws.guardduty":
        title = detail.get("title", "GuardDuty Alert")
        severity = detail.get("severity", "Unknown")
        region = detail.get("region", "Unknown")
        return (
            f"[SOAR Alert] GuardDuty Finding\n"
            f"Title: {title}\n"
            f"Severity: {severity}\n"
            f"Region: {region}\n"
        )

    # Handle CloudWatch alarms
    elif source == "aws.cloudwatch":
        alarm = detail.get("alarmName", "Unnamed Alarm")
        state = detail.get("state", {}).get("value", "Unknown")
        reason = detail.get("state", {}).get("reason", "No reason provided.")
        return (
            f"[SOAR Alert] CloudWatch Alarm\n"
            f"Alarm: {alarm}\n"
            f"State: {state}\n"
            f"Reason: {reason}\n"
        )

    # Fallback for any other event
    return f"[SOAR Alert] {detail_type}\nSource: {source}\nDetails:\n{json.dumps(detail, indent=2)}"
