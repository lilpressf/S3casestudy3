########################################
# AWS Managed Microsoft AD for Workstations
########################################

resource "aws_directory_service_directory" "workstations" {
  name     = var.directory_domain_name
  password = var.directory_admin_password
  type     = "MicrosoftAD"
  edition  = "Standard"

  vpc_settings {
    vpc_id     = aws_vpc.main.id
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id,
    ]
  }

  tags = {
    Name        = "innovatech-workstations-directory"
    Environment = "dev"
    Project     = "cs3-innovatech"
  }
}

########################################
# DHCP options so instances use AD DNS
########################################

# Ensure EC2 instances in the VPC resolve the directory DNS name
# (corp.innovatech.local) using the DNS servers managed by
# AWS Directory Service. This is required for domain join and
# for AD PowerShell cmdlets on the directory-admin instance.
resource "aws_vpc_dhcp_options" "directory_dns" {
  domain_name         = var.directory_domain_name
  domain_name_servers = aws_directory_service_directory.workstations.dns_ip_addresses

  tags = {
    Name        = "innovatech-directory-dhcp"
    Environment = "dev"
    Project     = "cs3-innovatech"
  }
}

resource "aws_vpc_dhcp_options_association" "directory_dns" {
  vpc_id          = aws_vpc.main.id
  dhcp_options_id = aws_vpc_dhcp_options.directory_dns.id
}
