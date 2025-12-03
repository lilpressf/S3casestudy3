resource "aws_eks_cluster" "main" {
  name     = "innovatech-eks"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.30" 

  vpc_config {
    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    # For now, keep the API server public so you can access it easily
    endpoint_public_access  = true
    endpoint_private_access = false
  }

  tags = {
    Environment = "dev"
    Project     = "cs3-innovatech"
  }

  # Enable control plane logging for better observability and auditability
  enabled_cluster_log_types = [
    "api",
    "audit",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]
}
