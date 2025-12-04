variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_a_cidr" {
  description = "CIDR block for public subnet A"
  type        = string
  default     = "10.0.1.0/24"
}

variable "public_subnet_b_cidr" {
  description = "CIDR block for public subnet B"
  type        = string
  default     = "10.0.2.0/24"
}

variable "private_subnet_a_cidr" {
  description = "CIDR block for private subnet A"
  type        = string
  default     = "10.0.3.0/24"
}

variable "private_subnet_b_cidr" {
  description = "CIDR block for private subnet B"
  type        = string
  default     = "10.0.4.0/24"
}

variable "ssh_public_key" {
  description = "SSH public key contents"
  type        = string
  sensitive   = true
}

variable "ssh_cidr" {
  description = "CIDR block allowed SSH access"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for ALB"
  type        = string
  default     = ""
}

variable "workspaces_directory_id" {
  description = "AWS WorkSpaces Directory ID"
  type        = string
  default     = ""
}

variable "workspaces_bundle_id" {
  description = "AWS WorkSpaces Bundle ID"
  type        = string
  default     = ""
}
