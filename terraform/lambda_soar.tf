data "aws_iam_policy_document" "soar_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "soar_exec" {
  name               = "soar-exec-role"
  assume_role_policy = data.aws_iam_policy_document.soar_assume.json
}

# Permissions
resource "aws_iam_role_policy" "soar_inline" {
  role = aws_iam_role.soar_exec.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = [
          "logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"
        ], Resource = "*" },
      { Effect = "Allow", Action = ["sns:Publish"], Resource = aws_sns_topic.soar_alerts.arn },
      { Effect = "Allow", Action = ["dynamodb:PutItem"], Resource = aws_dynamodb_table.app.arn },
      { Effect = "Allow", Action = [
          "ec2:DescribeInstances", "ec2:DescribeNetworkInterfaces",
          "ec2:CreateTags", "ec2:ModifyInstanceAttribute"
        ], Resource = "*" }
    ]
  })
}

# Managed basics for VPC logging 
resource "aws_iam_role_policy_attachment" "soar_basic" {
  role       = aws_iam_role.soar_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "soar" {
  name              = "/aws/lambda/soar-handler"
  retention_in_days = 14
}

resource "aws_lambda_function" "soar" {
  function_name    = "soar-handler"
  role             = aws_iam_role.soar_exec.arn
  handler          = "soar.handler"
  runtime          = "python3.12"
  filename         = "build/soar.zip"
  source_code_hash = filebase64sha256("build/soar.zip")
  timeout          = 60
  memory_size      = 512

  environment {
    variables = {
      TABLE_NAME   = aws_dynamodb_table.app.name
      SNS_TOPIC_ARN = aws_sns_topic.soar_alerts.arn
    }
  }

  depends_on = [aws_cloudwatch_log_group.soar, aws_iam_role_policy_attachment.soar_basic]
}


