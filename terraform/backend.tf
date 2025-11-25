terraform {
  backend "s3" {
    bucket = "daan-terraform-state-bucket"
    key    = "test/terraform.tfstate"
    region = "eu-central-1"
    encrypt = true
  }
}