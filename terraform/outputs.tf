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

output "ecr_backend_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "alb_dns_name" {
  description = "Public DNS name for the ALB"
  value       = aws_lb.public_alb.dns_name
}

output "alb_target_group_arn" {
  description = "Target group ARN for wiring Kubernetes NodePort services"
  value       = aws_lb_target_group.eks_nodes.arn
}
