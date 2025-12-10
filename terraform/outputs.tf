###############################################
# Networking
###############################################
output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = [
    aws_subnet.public_a.id,
    aws_subnet.public_b.id,
  ]
}

output "private_subnet_ids" {
  value = [
    aws_subnet.private_a.id,
    aws_subnet.private_b.id,
  ]
}

###############################################
# EKS
###############################################
output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "eks_node_group_name" {
  value = aws_eks_node_group.main.node_group_name
}

output "eks_node_role_arn" {
  value = aws_iam_role.eks_node_role.arn
}

###############################################
# IAM (IRSA)
###############################################
output "lbc_irsa_role_arn" {
  value = aws_iam_role.lbc_irsa.arn
}

output "backend_irsa_role_arn" {
  value = aws_iam_role.backend_irsa.arn
}

###############################################
# Cognito – required for GitHub Actions workflow
###############################################
output "cognito_user_pool_id" {
  value = aws_cognito_user_pool.portal.id
}

output "cognito_user_pool_client_id" {
  value = aws_cognito_user_pool_client.portal_client.id
}

output "cognito_user_pool_client_secret" {
  value = aws_cognito_user_pool_client.portal_client.client_secret
}

output "cognito_user_pool_domain" {
  value = aws_cognito_user_pool_domain.portal_domain.domain
}

output "cognito_user_pool_arn" {
  value = aws_cognito_user_pool.portal.arn
}

###############################################
# ACM certificate
###############################################
output "acm_certificate_arn" {
  value = aws_acm_certificate_validation.portal.certificate_arn
}
