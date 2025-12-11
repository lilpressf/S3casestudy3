# Windows-based EC2 Workstations for Employees
# Uses SSM for management and CloudWatch for logging.

########################################
# Windows Server AMI
########################################

data "aws_ami" "windows_server" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

########################################
# IAM Role / Instance Profile for SSM
########################################

resource "aws_iam_service_linked_role" "ssm" {
  aws_service_name = "ssm.amazonaws.com"
  description      = "Service-linked role so Systems Manager can manage EC2 workstations"
}

resource "aws_iam_role" "workstation_role" {
  name = "workstation-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action   = "sts:AssumeRole"
    }]
  })

  tags = {
    Name        = "workstation-ssm-role"
    Environment = "dev"
    Project     = "cs3-innovatech"
  }
}

# SSM core
resource "aws_iam_role_policy_attachment" "workstation_ssm" {
  role       = aws_iam_role.workstation_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch Agent policy
resource "aws_iam_role_policy_attachment" "workstation_cloudwatch" {
  role       = aws_iam_role.workstation_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Allow workstations (including the directory-admin instance) to join
# the AWS Managed Microsoft AD directory via AWS-JoinDirectoryServiceDomain.
resource "aws_iam_role_policy" "workstation_directory_access" {
  role = aws_iam_role.workstation_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ds:CreateComputer",
          "ds:DescribeDirectories"
        ],
        Resource = "arn:aws:ds:${var.aws_region}:${data.aws_caller_identity.current.account_id}:directory/${aws_directory_service_directory.workstations.id}"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "workstation_profile" {
  name = "workstation-ssm-profile"
  role = aws_iam_role.workstation_role.name
}

########################################
# Launch Template for Windows Workstations
########################################

resource "aws_launch_template" "workstation" {
  name_prefix   = "workstation-"
  image_id      = data.aws_ami.windows_server.id
  instance_type = "t3.micro" 

  iam_instance_profile {
    name = aws_iam_instance_profile.workstation_profile.name
  }

  vpc_security_group_ids = [aws_security_group.workstation_sg.id]

  monitoring {
    enabled = true
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = 80
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Simplified PowerShell bootstrap (cleaned up for syntax)
  user_data = base64encode(<<-EOF
    <powershell>
    # Set timezone
    Set-TimeZone -Id "W. Europe Standard Time"

    # Ensure SSM Agent is installed and running so the instance shows up in Systems Manager
    $region = "${var.aws_region}"
    $ssmInstaller = "$env:TEMP\\AmazonSSMAgentSetup.exe"
    $ssmUrl = "https://s3.$region.amazonaws.com/amazon-ssm-$region/latest/windows_amd64/AmazonSSMAgentSetup.exe"
    try {
      Invoke-WebRequest -Uri $ssmUrl -OutFile $ssmInstaller -UseBasicParsing
      Start-Process -FilePath $ssmInstaller -ArgumentList "/S" -Wait
      Set-Service -Name "AmazonSSMAgent" -StartupType Automatic -ErrorAction SilentlyContinue
      Start-Service -Name "AmazonSSMAgent" -ErrorAction SilentlyContinue
    } catch {
      Write-Host "Failed to install/start SSM Agent: $_"
    }

    # Install CloudWatch Agent
    $agentUrl = "https://s3.amazonaws.com/amazoncloudwatch-agent/windows/amd64/latest/amazon-cloudwatch-agent.msi"
    $agentPath = "$env:TEMP\\amazon-cloudwatch-agent.msi"
    Invoke-WebRequest -Uri $agentUrl -OutFile $agentPath
    Start-Process msiexec.exe -ArgumentList "/i $agentPath /qn" -Wait

    # Install Chocolatey
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

    # Common tools
    choco install -y git
    choco install -y vscode
    choco install -y googlechrome
    choco install -y 7zip

    # Enable RDP and firewall
    Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -Name "fDenyTSConnections" -Value 0
    Enable-NetFirewallRule -DisplayGroup "Remote Desktop"

    # Enable automatic updates
    $AutoUpdatePath = "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU"
    If (-Not (Test-Path $AutoUpdatePath)) {
        New-Item -Path $AutoUpdatePath -Force | Out-Null
    }
    Set-ItemProperty -Path $AutoUpdatePath -Name "NoAutoUpdate" -Value 0
    Set-ItemProperty -Path $AutoUpdatePath -Name "AUOptions" -Value 4

    # Marker
    New-Item -Path "C:\\workstation-ready.txt" -ItemType File -Value "Workstation provisioned successfully at $(Get-Date)" -Force

    Write-Host "Windows workstation setup completed successfully"
    </powershell>
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name        = "employee-workstation-windows"
      Environment = "dev"
      Project     = "cs3-innovatech"
      ManagedBy   = "terraform"
      OS          = "Windows Server 2022"
    }
  }

  tags = {
    Name        = "workstation-launch-template-windows"
    Environment = "dev"
    Project     = "cs3-innovatech"
  }
}

########################################
# SSM Documents (optional, for baseline/apps)
########################################

resource "aws_ssm_document" "security_baseline" {
  name            = "Workstation-Security-Baseline"
  document_type   = "Command"
  document_format = "YAML"

  content = <<-DOC
    schemaVersion: '2.2'
    description: Apply security baseline to Windows workstations
    mainSteps:
      - action: aws:runPowerShellScript
        name: applySecurityBaseline
        inputs:
          runCommand:
            - |
              Set-Service -Name "RemoteRegistry" -StartupType Disabled -ErrorAction SilentlyContinue
              Stop-Service -Name "RemoteRegistry" -Force -ErrorAction SilentlyContinue
              Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
              net accounts /minpwlen:12
              net accounts /maxpwage:90
              net accounts /minpwage:1
              net accounts /uniquepw:5
              net user guest /active:no
              auditpol /set /category:"Account Logon" /success:enable /failure:enable
              auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable
              auditpol /set /category:"Object Access" /success:enable /failure:enable
              Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue
              Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue
              Update-MpSignature -ErrorAction SilentlyContinue
              $AutoUpdatePath = "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU"
              If (-Not (Test-Path $AutoUpdatePath)) {
                  New-Item -Path $AutoUpdatePath -Force | Out-Null
              }
              Set-ItemProperty -Path $AutoUpdatePath -Name "NoAutoUpdate" -Value 0
              Set-ItemProperty -Path $AutoUpdatePath -Name "AUOptions" -Value 4
              Write-Output "Security baseline applied successfully"
  DOC

  tags = {
    Name        = "security-baseline-windows"
    Environment = "dev"
    Project     = "cs3-innovatech"
  }
}

resource "aws_ssm_document" "deploy_applications" {
  name            = "Workstation-Deploy-Apps"
  document_type   = "Command"
  document_format = "YAML"

  content = <<-DOC
    schemaVersion: '2.2'
    description: Deploy standard applications to Windows workstations
    parameters:
      Department:
        type: String
        description: Employee department (Engineering, Sales, HR, etc.)
        default: "Engineering"
    mainSteps:
      - action: aws:runPowerShellScript
        name: deployApplications
        inputs:
          runCommand:
            - |
              $Department = "{{ Department }}"

              if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
                  Write-Output "Installing Chocolatey..."
                  Set-ExecutionPolicy Bypass -Scope Process -Force
                  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
                  iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
              }

              Write-Output "Installing common applications..."
              choco install -y googlechrome
              choco install -y 7zip
              choco install -y adobereader
              choco install -y zoom
              choco install -y slack
              choco install -y vscode

              switch ($Department) {
                  {($_ -eq "Engineering") -or ($_ -eq "engineering")} {
                      Write-Output "Installing developer tools..."
                      choco install -y git
                      choco install -y vscode
                      choco install -y python
                      choco install -y nodejs
                      choco install -y docker-desktop
                      choco install -y postman
                  }
                  {($_ -eq "Sales") -or ($_ -eq "sales")} {
                      Write-Output "Installing sales tools..."
                      choco install -y microsoft-teams
                  }
                  {($_ -eq "HR") -or ($_ -eq "hr")} {
                      Write-Output "Installing HR tools..."
                      choco install -y microsoft-teams
                  }
                  default {
                      Write-Output "Installing standard office tools..."
                      choco install -y microsoft-teams
                  }
              }

              Write-Output "Applications deployed successfully for $Department"
  DOC

  tags = {
    Name        = "deploy-applications-windows"
    Environment = "dev"
    Project     = "cs3-innovatech"
  }
}
