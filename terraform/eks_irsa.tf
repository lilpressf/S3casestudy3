resource "aws_iam_role" "backend_irsa" {
  name = "backend-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = aws_iam_openid_connect_provider.eks.arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:default:backend-sa",
            "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "backend_dynamodb_policy" {
  role = aws_iam_role.backend_irsa.id

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
          "lambda:InvokeFunction"
        ],
        Resource = "*"
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
