# Lambda Security Group
resource "aws_security_group" "lambda_sg" {
  name   = "lambda-sg"
  vpc_id = aws_vpc.main.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "lambda-sg" }
}

# Security Group for Workstations
resource "aws_security_group" "workstation_sg" {
  name   = "workstation-sg"
  vpc_id = aws_vpc.main.id

  # RDP from your IP (replace with your public IP or a VPN CIDR)
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

  # Allow all outbound for SSM, updates, etc.
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "workstation-sg"
    Environment = "dev"
    Project     = "cs3-innovatech"
  }
}