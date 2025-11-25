output "soar_lambda_name" {
  value = aws_lambda_function.soar.function_name
}

output "sns_topic_arn" {
  value = aws_sns_topic.soar_alerts.arn
}

output "nat_public_ip" {
  value = aws_instance.nat.public_ip
}

output "web_key_name" {
  value = aws_key_pair.web_key.key_name
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.app.name
}

output "cloudwatch_alarm_name" {
  value = aws_cloudwatch_metric_alarm.alb_5xx_sum.alarm_name
}

output "eventbridge_rules" {
  value = [
    aws_cloudwatch_event_rule.sechub_findings.name,
    aws_cloudwatch_event_rule.guardduty_findings.name,
    aws_cloudwatch_event_rule.cw_alarm_state.name
  ]
}

output "alb_dns_name" {
  value       = aws_lb.web_alb.dns_name
  description = "Public DNS name of the Application Load Balancer"
}

output "ecs_service_name" {
  value = aws_ecs_service.webserver.name
}

output "ecs_dns_name" {
  value = "webapp.${aws_service_discovery_private_dns_namespace.svc.name}"
}

output "ecs_log_group_name" {
  value = aws_cloudwatch_log_group.ecs_webapp.name
}
