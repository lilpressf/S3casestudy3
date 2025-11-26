# NAT Security Group
resource "aws_security_group" "nat_sg" {
  vpc_id = aws_vpc.main.id
  name   = "nat-sg"

  ingress {
    description = "Allow SSH from admin CIDR"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_cidr]
  }

ingress {
  description = "Allow traffic from both private subnets"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = [
    var.private_subnet_a_cidr,
    var.private_subnet_b_cidr
  ]
}

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "nat-sg" }
}

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
