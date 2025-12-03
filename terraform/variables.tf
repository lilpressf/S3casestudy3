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
  description = "Contents of your SSH public key"
  type        = string
  sensitive   = true
}

variable "ssh_cidr" {
  description = "CIDR block allowed to SSH into webservers"
  type        = string
  sensitive   = true
}

variable "eks_nodeport" {
  description = "NodePort exposed by your Kubernetes Service that the ALB should forward to"
  type        = number
  default     = 30080
}

variable "backend_service_port" {
  description = "Backend service port for ALB IP targets (used by the controller-managed ALB)"
  type        = number
  default     = 5000
}

variable "frontend_service_port" {
  description = "Frontend service port for ALB IP targets"
  type        = number
  default     = 80
}

variable "cognito_callback_urls" {
  description = "Allowed callback URLs for Cognito Hosted UI"
  type        = list(string)
  default     = ["http://localhost/"]
}

variable "cognito_logout_urls" {
  description = "Allowed logout URLs for Cognito Hosted UI"
  type        = list(string)
  default     = ["http://localhost/"]
}

variable "workspaces_directory_id" {
  description = "WorkSpaces Directory ID used to provision desktops"
  type        = string
  default     = ""
}

variable "workspaces_bundle_id" {
  description = "WorkSpaces Bundle ID for default app set"
  type        = string
  default     = ""
}

variable "hosted_zone_name" {
  description = "Public hosted zone domain name (managed in Route53)"
  type        = string
  default     = "daanwelten.nl"
}

variable "portal_subdomain" {
  description = "Subdomain for the portal (will be ALIASed to the ALB)"
  type        = string
  default     = "portal"
}

