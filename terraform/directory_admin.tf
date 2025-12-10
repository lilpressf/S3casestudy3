########################################
# Directory admin EC2 instance for managing AD users
########################################

resource "aws_instance" "directory_admin" {
  ami                    = data.aws_ami.windows_server.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.workstation_sg.id]

  iam_instance_profile = aws_iam_instance_profile.workstation_profile.name

  # Plain text user data; AWS provider will base64-encode it automatically.
  user_data = <<-EOF
    <powershell>
    # Install Active Directory PowerShell tools so SSM scripts can manage users
    try {
      Install-WindowsFeature RSAT-AD-PowerShell -IncludeAllSubFeature -ErrorAction Stop
    } catch {
      Write-Host "Failed to install RSAT-AD-PowerShell: $_"
    }
    </powershell>
  EOF

  tags = {
    Name        = "directory-admin"
    Environment = "dev"
    Project     = "cs3-innovatech"
    Role        = "directory-admin"
  }
}

resource "aws_ssm_association" "directory_admin_join" {
  name = "AWS-JoinDirectoryServiceDomain"

  targets {
    key    = "InstanceIds"
    values = [aws_instance.directory_admin.id]
  }

  parameters = {
    directoryId     = aws_directory_service_directory.workstations.id
    directoryName   = aws_directory_service_directory.workstations.name
    # Explicitly pass DNS IPs so the document can configure
    # the network adapter for the Managed Microsoft AD.
    dnsIpAddresses = jsonencode(aws_directory_service_directory.workstations.dns_ip_addresses)
  }

  depends_on = [
    aws_instance.directory_admin,
    aws_directory_service_directory.workstations,
    aws_iam_service_linked_role.ssm,
    aws_vpc_dhcp_options_association.directory_dns,
  ]
}
