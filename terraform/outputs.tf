output "vpc_id" {
  value       = aws_vpc.main.id
  description = "VPC ID"
}

output "public_subnet_ids" {
  value       = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  description = "Public subnet IDs"
}

output "private_subnet_ids" {
  value       = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  description = "Private subnet IDs"
}

output "eks_cluster_name" {
  value       = aws_eks_cluster.main.name
  description = "EKS cluster name"
}

output "eks_cluster_endpoint" {
  value       = aws_eks_cluster.main.endpoint
  description = "EKS cluster API server endpoint"
}

output "eks_cluster_certificate_authority" {
  value       = aws_eks_cluster.main.certificate_authority[0].data
  description = "EKS cluster CA data"
}

output "eks_node_group_name" {
  value       = aws_eks_node_group.default.node_group_name
  description = "EKS node group name"
}

output "employees_table_name" {
  value       = aws_dynamodb_table.employees.name
  description = "DynamoDB employees table name"
}

output "devices_table_name" {
  value       = aws_dynamodb_table.devices.name
  description = "DynamoDB devices table name"
}

output "audit_logs_table_name" {
  value       = aws_dynamodb_table.audit_logs.name
  description = "DynamoDB audit logs table name"
}

output "eks_node_role_arn" {
  description = "IAM role ARN for EKS worker nodes (for aws-auth mapping)"
  value       = aws_iam_role.eks_node_role.arn
}

output "ecr_backend_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "lbc_irsa_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller service account"
  value       = aws_iam_role.lbc_irsa.arn
}

output "backend_irsa_role_arn" {
  description = "IAM role ARN for the backend IRSA service account"
  value       = aws_iam_role.backend_irsa.arn
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID for portal authentication"
  value       = aws_cognito_user_pool.portal.id
}

output "cognito_user_pool_client_id" {
  description = "Cognito app client ID"
  value       = aws_cognito_user_pool_client.portal.id
}

output "cognito_issuer" {
  description = "Cognito OIDC issuer URL"
  value       = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.portal.id}"
}

output "cognito_user_pool_domain" {
  description = "Cognito user pool domain prefix"
  value       = aws_cognito_user_pool_domain.portal.domain
}

output "acm_certificate_arn" {
  value = aws_acm_certificate.portal.arn
}

output "cognito_user_pool_client_secret" {
  value     = aws_cognito_user_pool_client.portal.client_secret
  sensitive = true
}
