# EKS Cluster IAM Role
data "aws_iam_policy_document" "eks_cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_cluster_role" {
  name               = "eks-cluster-role"
  assume_role_policy = data.aws_iam_policy_document.eks_cluster_assume.json
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# EKS Nodegroup IAM Role
data "aws_iam_policy_document" "eks_node_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eks_node_role" {
  name               = "eks-node-role"
  assume_role_policy = data.aws_iam_policy_document.eks_node_assume.json
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_ecr_readonly" {
  role       = aws_iam_role.eks_node_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Give worker nodes the same app permissions the backend previously
# had via IRSA, so backend pods can use the node role instead.
resource "aws_iam_role_policy" "eks_node_backend_permissions" {
  role = aws_iam_role.eks_node_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ],
        Resource = [
          aws_dynamodb_table.employees.arn,
          "${aws_dynamodb_table.employees.arn}/index/email-index",
          aws_dynamodb_table.audit_logs.arn
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "cognito-idp:AdminCreateUser",
          "cognito-idp:AdminDisableUser",
          "cognito-idp:AdminAddUserToGroup",
          "cognito-idp:CreateGroup",
          "cognito-idp:AdminGetUser",
          "cognito-idp:ListUsers",
          "cognito-idp:GetGroup",
          "cognito-idp:ListGroups",
          "cognito-idp:AdminListGroupsForUser"
        ],
        Resource = [
          data.aws_cognito_user_pool.portal.arn,
          "${data.aws_cognito_user_pool.portal.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:CreateTags",
          "ec2:DescribeInstances",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "iam:PassRole"
        ],
        Resource = aws_iam_role.workstation_role.arn
      },
      {
        Effect = "Allow",
        Action = [
          "ssm:SendCommand"
        ],
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:document/Workstation-Security-Baseline",
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:document/Workstation-Deploy-Apps",
          "arn:aws:ssm:${var.aws_region}::document/AWS-JoinDirectoryServiceDomain",
          "arn:aws:ssm:${var.aws_region}::document/AWS-RunPowerShellScript",
          "arn:aws:ec2:${var.aws_region}:${data.aws_caller_identity.current.account_id}:instance/*"
        ]
      }
    ]
  })
}
