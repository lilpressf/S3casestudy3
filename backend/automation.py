import os
import uuid

import boto3
from botocore.exceptions import ClientError


class Automation:
    def __init__(self):
        self.region = os.getenv("AWS_REGION", "eu-central-1")
        self.user_pool_id = os.getenv("COGNITO_POOL_ID")

        # AWS SDK clients
        self.cognito = boto3.client("cognito-idp", region_name=self.region)
        self.ec2 = boto3.client("ec2", region_name=self.region)

        # For EC2 workstation provisioning
        self.workstation_lt_id = os.getenv("WORKSTATION_LT_ID", "")
        self.workstation_subnet_id = os.getenv("WORKSTATION_SUBNET_ID", "")

    # ------------- Identity (Cognito) -------------

    def ensure_group(self, group_name: str):
        if not group_name:
            return
        try:
            self.cognito.get_group(UserPoolId=self.user_pool_id, GroupName=group_name)
        except self.cognito.exceptions.ResourceNotFoundException:
            self.cognito.create_group(
                UserPoolId=self.user_pool_id,
                GroupName=group_name,
            )

    def onboard_identity(self, email: str, name: str, group: str):
        if not self.user_pool_id:
            return {"status": "skipped", "reason": "No user pool configured"}

        username = email
        temp_password = f"{uuid.uuid4()}Aa1!"
        try:
            self.cognito.admin_create_user(
                UserPoolId=self.user_pool_id,
                Username=username,
                TemporaryPassword=temp_password,
                UserAttributes=[
                    {"Name": "email", "Value": email},
                    {"Name": "email_verified", "Value": "true"},
                    {"Name": "name", "Value": name},
                ],
                MessageAction="SUPPRESS",
            )
            if group:
                self.ensure_group(group)
                self.cognito.admin_add_user_to_group(
                    UserPoolId=self.user_pool_id,
                    Username=username,
                    GroupName=group,
                )
            return {
                "status": "created",
                "username": username,
                "temp_password": temp_password,
            }
        except ClientError as exc:
            return {"status": "error", "error": str(exc)}

    def disable_identity(self, email: str):
        if not self.user_pool_id:
            return {"status": "skipped", "reason": "No user pool configured"}
        try:
            self.cognito.admin_disable_user(
                UserPoolId=self.user_pool_id,
                Username=email,
            )
            return {"status": "disabled"}
        except ClientError as exc:
            return {"status": "error", "error": str(exc)}

    # ------------- EC2 Workstations -------------

    def create_workstation(self, email: str, department: str):
        """
        Create an EC2-based Windows workstation for an employee.
        Uses a pre-created launch template and a private subnet.
        """
        if not self.workstation_lt_id or not self.workstation_subnet_id:
            return {
                "status": "skipped",
                "reason": "No workstation LT/subnet configured",
            }

        try:
            tags = [
                {"Key": "EmployeeEmail", "Value": email},
                {"Key": "Department", "Value": department},
                {"Key": "Purpose", "Value": "Workstation"},
            ]

            resp = self.ec2.run_instances(
                LaunchTemplate={"LaunchTemplateId": self.workstation_lt_id},
                MinCount=1,
                MaxCount=1,
                SubnetId=self.workstation_subnet_id,
                TagSpecifications=[
                    {
                        "ResourceType": "instance",
                        "Tags": tags,
                    },
                ],
            )
            instance = resp["Instances"][0]
            return {
                "status": instance.get("State", {}).get("Name", "pending"),
                "instance_id": instance["InstanceId"],
            }
        except ClientError as exc:
            return {"status": "error", "error": str(exc)}

    def terminate_workstation(self, instance_id: str):
        if not instance_id:
            return {"status": "skipped", "reason": "No instance id"}
        try:
            self.ec2.terminate_instances(InstanceIds=[instance_id])
            return {"status": "terminating"}
        except ClientError as exc:
            return {"status": "error", "error": str(exc)}