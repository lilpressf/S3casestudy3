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

# SSH Key Pair
resource "aws_key_pair" "web_key" {
  key_name   = "web-key"
  public_key = var.ssh_public_key
}
