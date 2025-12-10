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

