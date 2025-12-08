import os
import uuid
import boto3
from botocore.exceptions import ClientError


class Automation:
    def __init__(self):
        self.region = os.getenv("AWS_REGION", "eu-central-1")
        self.user_pool_id = os.getenv("COGNITO_POOL_ID")
        self.directory_id = os.getenv("WORKSPACES_DIRECTORY_ID", "")
        self.bundle_id = os.getenv("WORKSPACES_BUNDLE_ID", "")
        self.cognito = boto3.client("cognito-idp", region_name=self.region)
        self.workspaces = boto3.client("workspaces", region_name=self.region)

    def ensure_group(self, group_name: str):
        if not group_name:
            return
        try:
            self.cognito.get_group(UserPoolId=self.user_pool_id, GroupName=group_name)
        except self.cognito.exceptions.ResourceNotFoundException:
            self.cognito.create_group(UserPoolId=self.user_pool_id, GroupName=group_name)

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
                    UserPoolId=self.user_pool_id, Username=username, GroupName=group
                )
            return {"status": "created", "username": username, "temp_password": temp_password}
        except ClientError as exc:
            return {"status": "error", "error": str(exc)}

    def provision_workspace(self, email: str):
        if not self.directory_id or not self.bundle_id:
            return {"status": "skipped", "reason": "No WorkSpaces directory/bundle configured"}
        try:
            resp = self.workspaces.create_workspaces(
                Workspaces=[
                    {
                        "DirectoryId": self.directory_id,
                        "UserName": email,
                        "BundleId": self.bundle_id,
                    }
                ]
            )
            ws = resp.get("PendingRequests", [])
            if not ws:
                return {"status": "error", "error": "No workspace created"}
            item = ws[0]
            return {"status": item.get("State", "UNKNOWN"), "workspace_id": item.get("WorkspaceId")}
        except ClientError as exc:
            return {"status": "error", "error": str(exc)}

    def terminate_workspace(self, workspace_id: str):
        if not workspace_id:
            return {"status": "skipped", "reason": "No workspace id"}
        try:
            self.workspaces.terminate_workspaces(
                TerminateWorkspaceRequests=[{"WorkspaceId": workspace_id}]
            )
            return {"status": "terminating"}
        except ClientError as exc:
            return {"status": "error", "error": str(exc)}

    def disable_identity(self, email: str):
        if not self.user_pool_id:
            return {"status": "skipped", "reason": "No user pool configured"}
        try:
            self.cognito.admin_disable_user(UserPoolId=self.user_pool_id, Username=email)
            return {"status": "disabled"}
        except ClientError as exc:
            return {"status": "error", "error": str(exc)}
