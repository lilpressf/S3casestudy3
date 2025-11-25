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

variable "db_username" {
  description = "Database username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Contents of your SSH public key"
  type        = string
  sensitive   = true
}

variable "ssh_cidr" {
  description = "CIDR block allowed to SSH into webservers"
  type        = string
  sensitive   = true
}

variable "notify_email" {
  description = "Email to receive SOAR alerts"
  type        = string
}

variable "ecr_image_uri" {
  description = "URI of the container image in ECR"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
  default     = 8080
}