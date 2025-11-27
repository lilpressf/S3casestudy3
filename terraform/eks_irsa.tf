resource "aws_iam_role" "backend_irsa" {
  name = "backend-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
    }]
  })

  depends_on = [
    aws_iam_openid_connect_provider.eks
  ]
}


resource "aws_iam_role_policy" "backend_dynamodb_policy" {
  role = aws_iam_role.backend_irsa.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:GetItem",
        "dynamodb:Scan"
      ],
      Resource = aws_dynamodb_table.employee.arn
    }]
  })
}
