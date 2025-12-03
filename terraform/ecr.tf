resource "aws_ecr_repository" "backend" {
  name = "innovatech-backend"

  image_scanning_configuration {
    scan_on_push = true
  }

  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Project     = "cs3-innovatech"
    Environment = "dev"
  }
}

resource "aws_ecr_repository" "frontend" {
  name = "innovatech-frontend"

  image_scanning_configuration {
    scan_on_push = true
  }

  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Project     = "cs3-innovatech"
    Environment = "dev"
  }
}
