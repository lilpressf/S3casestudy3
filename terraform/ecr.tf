resource "aws_ecr_repository" "backend" {
  name = "innovatech-backend"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = "cs3-innovatech"
  }
}

resource "aws_ecr_repository" "frontend" {
  name = "innovatech-frontend"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = "cs3-innovatech"
  }
}
