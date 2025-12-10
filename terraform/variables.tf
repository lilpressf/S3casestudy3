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

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for ALB"
  type        = string
  default     = "arn:aws:acm:eu-central-1:846244128735:certificate/7557e636-a570-45ef-a05c-9a5a9f0faaf6"
}

variable "ssh_cidr" {
  description = "CIDR used for SSH/RDP admin access to workstations"
  type        = string
  default     = "0.0.0.0/0" 
}

variable "directory_domain_name" {
  description = "FQDN for the AWS Managed Microsoft AD directory"
  type        = string
  default     = "corp.innovatech.local"
}

variable "directory_admin_password" {
  description = "Admin password for the AWS Managed Microsoft AD directory"
  type        = string
  sensitive   = true
}
