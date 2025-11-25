resource "aws_sns_topic" "soar_alerts" {
  name = "soar-alerts"
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.soar_alerts.arn
  protocol  = "email"
  endpoint  = var.notify_email
}

