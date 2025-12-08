import boto3
import os

def dynamodb_table(table_name):
    return boto3.resource(
        "dynamodb",
        region_name=os.getenv("AWS_REGION", "eu-central-1")
    ).Table(table_name)
