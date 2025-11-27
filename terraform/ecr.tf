resource "aws_ecr_repository" "backend" {
  name = "innovatech-backend"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Project = "cs3-innovatech"
  }
}
