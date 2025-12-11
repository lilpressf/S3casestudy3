########################################
# Pod logs to CloudWatch (aws-for-fluent-bit)
########################################

data "aws_iam_policy_document" "cw_fluentbit_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:aws-observability:aws-for-fluent-bit"]
    }
  }
}

resource "aws_iam_role" "cw_fluentbit_irsa" {
  name               = "eks-cw-fluentbit-irsa"
  assume_role_policy = data.aws_iam_policy_document.cw_fluentbit_assume_role.json
}

resource "aws_cloudwatch_log_group" "eks_pods" {
  name              = "/aws/eks/innovatech/pods"
  retention_in_days = 30
}

resource "aws_iam_policy" "cw_fluentbit_policy" {
  name = "EKSFluentBitCloudWatchLogsPolicy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:DescribeLogStreams",
          "logs:PutLogEvents"
        ],
        Resource = [
          "${aws_cloudwatch_log_group.eks_pods.arn}",
          "${aws_cloudwatch_log_group.eks_pods.arn}:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cw_fluentbit_attach" {
  role       = aws_iam_role.cw_fluentbit_irsa.name
  policy_arn = aws_iam_policy.cw_fluentbit_policy.arn
}

resource "helm_release" "aws_for_fluent_bit" {
  name       = "aws-for-fluent-bit"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  namespace  = "aws-observability"

  create_namespace = true

  set {
    name  = "cloudWatch.enabled"
    value = "true"
  }

  set {
    name  = "cloudWatch.logGroupName"
    value = aws_cloudwatch_log_group.eks_pods.name
  }

  set {
    name  = "cloudWatch.region"
    value = var.aws_region
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-for-fluent-bit"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cw_fluentbit_irsa.arn
  }

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.default,
    aws_iam_role.cw_fluentbit_irsa,
    aws_iam_role_policy_attachment.cw_fluentbit_attach,
  ]
}

