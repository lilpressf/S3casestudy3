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

output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}

output "eks_node_group_name" {
  value = aws_eks_node_group.default.node_group_name
}

output "eks_node_role_arn" {
  value = aws_iam_role.eks_node_role.arn
}

output "lbc_irsa_role_arn" {
  value = aws_iam_role.lbc_irsa.arn
}

output "backend_irsa_role_arn" {
  value = aws_iam_role.backend_irsa.arn
}

# Cognito values from data sources (read‑only)
output "cognito_user_pool_id" {
  value = data.aws_cognito_user_pool.portal.id
}

output "cognito_user_pool_client_id" {
  value = data.aws_cognito_user_pool_client.portal.id
}

# Optional: Cognito domain if you also add a data source for it
# output "cognito_user_pool_domain" {
#   value = "innovatech-b37ae2b2"
# }

