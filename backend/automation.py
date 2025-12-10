import os
import uuid

import boto3
from botocore.exceptions import ClientError, BotoCoreError


class Automation:
    def __init__(self):
        self.region = os.getenv("AWS_REGION", "eu-central-1")
        self.user_pool_id = os.getenv("COGNITO_POOL_ID")
        self.directory_id = os.getenv("DIRECTORY_ID", "")
        self.directory_name = os.getenv("DIRECTORY_NAME", "")
        self.directory_admin_instance_id = os.getenv("DIRECTORY_ADMIN_INSTANCE_ID", "")
        self.directory_admin_password = os.getenv("DIRECTORY_ADMIN_PASSWORD", "")

        # AWS SDK clients
        self.cognito = boto3.client("cognito-idp", region_name=self.region)
        self.ec2 = boto3.client("ec2", region_name=self.region)
        self.ssm = boto3.client("ssm", region_name=self.region)

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
        """
        Provision identity in both Cognito (for portal access) and
        AWS Managed Microsoft AD (for workstation logon). Returns a
        combined status so the API can audit what happened where.
        """
        username = email
        temp_password = f"{uuid.uuid4()}Aa1!"

        # 1) Cognito user (portal identity) – for this project,
        # employee portal logins are handled via AD only. Admin
        # Cognito users are created manually, not by this flow.
        cognito_result: dict = {
            "status": "skipped",
            "reason": "Employees are created only in Active Directory",
        }

        # 2) Active Directory user (workstation logon)
        ad_result: dict
        if not (self.directory_id and self.directory_name and self.directory_admin_instance_id and self.directory_admin_password):
            ad_result = {
                "status": "skipped",
                "reason": "Directory or admin credentials not configured",
            }
        else:
            # very simple mapping: use local-part of email as sAMAccountName
            sam_account_name = email.split("@")[0]
            admin_upn = f"Admin@{self.directory_name}"
            # basic PowerShell to create or enable the user
            # NOTE: assumes directory_admin_password does not contain single quotes;
            # if it does, they are doubled for PowerShell literal.
            pwd_literal = self.directory_admin_password.replace("'", "''")
            # basic PowerShell to create or enable the user
            commands = [
                "Import-Module ActiveDirectory",
                f"$UserPrincipalName = '{email}'",
                f"$Sam = '{sam_account_name}'",
                f"$Name = '{name}'",
                f"$Dept = '{group}'",
                f"$UserPassword = ConvertTo-SecureString '{temp_password}' -AsPlainText -Force",
                f"$AdminPassword = ConvertTo-SecureString '{pwd_literal}' -AsPlainText -Force",
                f"$Cred = New-Object System.Management.Automation.PSCredential ('{admin_upn}', $AdminPassword)",
                "$existing = Get-ADUser -Filter \"UserPrincipalName -eq '$UserPrincipalName'\" -ErrorAction SilentlyContinue",
                "if ($existing) {",
                "  Enable-ADAccount -Identity $existing.SamAccountName -Credential $Cred",
                "  Write-Output 'UserExists'",
                "} else {",
                "  New-ADUser -Name $Name -SamAccountName $Sam -UserPrincipalName $UserPrincipalName "
                "    -Department $Dept -AccountPassword $UserPassword -Enabled $true -Credential $Cred",
                "  Write-Output 'UserCreated'",
                "}",
            ]
            try:
                resp = self.ssm.send_command(
                    InstanceIds=[self.directory_admin_instance_id],
                    DocumentName="AWS-RunPowerShellScript",
                    Parameters={"commands": commands},
                    TimeoutSeconds=600,
                )
                cmd_id = resp.get("Command", {}).get("CommandId")
                ad_result = {
                    "status": "submitted",
                    "command_id": cmd_id,
                    "temp_password": temp_password,
                }
            except (ClientError, BotoCoreError) as exc:
                ad_result = {"status": "error", "error": str(exc)}

        # Derive a simple top-level status for easier handling:
        # - "error"    if either backend reports error
        # - "skipped"  if both were skipped
        # - "submitted" otherwise (commands sent / user created)
        statuses = []
        for part in (cognito_result, ad_result):
            if isinstance(part, dict) and "status" in part:
                statuses.append(part["status"])

        if any(s == "error" for s in statuses):
            overall = "error"
        elif statuses and all(s == "skipped" for s in statuses):
            overall = "skipped"
        else:
            overall = "submitted"

        return {
            "status": overall,
            "cognito": cognito_result,
            "directory": ad_result,
        }

    def disable_identity(self, email: str):
        """
        Disable / delete identity in both Cognito and AD where possible.
        """
        results = {}

        # 1) Cognito – admins are managed separately; employee
        # accounts are only disabled in Active Directory.
        results["cognito"] = {
            "status": "skipped",
            "reason": "Employees are disabled only in Active Directory",
        }

        # 2) Active Directory
        if not (self.directory_id and self.directory_name and self.directory_admin_instance_id and self.directory_admin_password):
            results["directory"] = {
                "status": "skipped",
                "reason": "Directory or admin credentials not configured",
            }
        else:
            sam_account_name = email.split("@")[0]
            admin_upn = f"Admin@{self.directory_name}"
            pwd_literal = self.directory_admin_password.replace("'", "''")
            commands = [
                "Import-Module ActiveDirectory",
                f"$Sam = '{sam_account_name}'",
                f"$AdminPassword = ConvertTo-SecureString '{pwd_literal}' -AsPlainText -Force",
                f"$Cred = New-Object System.Management.Automation.PSCredential ('{admin_upn}', $AdminPassword)",
                "$user = Get-ADUser -Identity $Sam -ErrorAction SilentlyContinue",
                "if ($user) {",
                "  Disable-ADAccount -Identity $Sam -Credential $Cred",
                "  Write-Output 'UserDisabled'",
                "} else {",
                "  Write-Output 'UserNotFound'",
                "}",
            ]
            try:
                resp = self.ssm.send_command(
                    InstanceIds=[self.directory_admin_instance_id],
                    DocumentName="AWS-RunPowerShellScript",
                    Parameters={"commands": commands},
                    TimeoutSeconds=600,
                )
                cmd_id = resp.get("Command", {}).get("CommandId")
                results["directory"] = {
                    "status": "submitted",
                    "command_id": cmd_id,
                }
            except (ClientError, BotoCoreError) as exc:
                results["directory"] = {"status": "error", "error": str(exc)}

        # Same convention as onboard_identity: provide a top-level roll‑up.
        statuses = []
        for part in results.values():
            if isinstance(part, dict) and "status" in part:
                statuses.append(part["status"])

        if any(s == "error" for s in statuses):
            overall = "error"
        elif statuses and all(s == "skipped" for s in statuses):
            overall = "skipped"
        else:
            overall = "submitted"

        results["status"] = overall
        return results

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
            instance_id = instance["InstanceId"]

            baseline_cmd_id = None
            apps_cmd_id = None
            join_cmd_id = None

            # 1) Apply security baseline
            try:
                baseline_cmd = self.ssm.send_command(
                    InstanceIds=[instance_id],
                    DocumentName="Workstation-Security-Baseline",
                    TimeoutSeconds=600,
                )
                baseline_cmd_id = baseline_cmd.get("Command", {}).get("CommandId")
            except (ClientError, BotoCoreError):
                baseline_cmd_id = None

            # 2) Join AWS Managed Microsoft AD (if configured)
            if self.directory_id and self.directory_name:
                try:
                    join_cmd = self.ssm.send_command(
                        InstanceIds=[instance_id],
                        DocumentName="AWS-JoinDirectoryServiceDomain",
                        Parameters={
                            "directoryId": [self.directory_id],
                            "directoryName": [self.directory_name],
                        },
                        TimeoutSeconds=600,
                    )
                    join_cmd_id = join_cmd.get("Command", {}).get("CommandId")
                except (ClientError, BotoCoreError):
                    join_cmd_id = None

            # 3) Deploy department-specific applications
            try:
                apps_cmd = self.ssm.send_command(
                    InstanceIds=[instance_id],
                    DocumentName="Workstation-Deploy-Apps",
                    Parameters={"Department": [department]},
                    TimeoutSeconds=600,
                )
                apps_cmd_id = apps_cmd.get("Command", {}).get("CommandId")
            except (ClientError, BotoCoreError):
                apps_cmd_id = None

            return {
                "status": instance.get("State", {}).get("Name", "pending"),
                "instance_id": instance_id,
                "baseline_command_id": baseline_cmd_id,
                "apps_command_id": apps_cmd_id,
                "join_domain_command_id": join_cmd_id,
            }
        except (ClientError, BotoCoreError) as exc:
            return {"status": "error", "error": str(exc)}

    def terminate_workstation(self, instance_id: str):
        if not instance_id:
            return {"status": "skipped", "reason": "No instance id"}
        try:
            self.ec2.terminate_instances(InstanceIds=[instance_id])
            return {"status": "terminating"}
        except (ClientError, BotoCoreError) as exc:
            return {"status": "error", "error": str(exc)}
