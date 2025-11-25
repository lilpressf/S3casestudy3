# CloudWatch Alarms

# ALB 5xx Error Alarm 
resource "aws_cloudwatch_metric_alarm" "alb_5xx_sum" {
  alarm_name          = "alb-5xx-errors"
  alarm_description   = "Triggers if ALB reports 5xx errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 0
  treat_missing_data  = "notBreaching"
  period              = 60
  statistic           = "Sum"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  dimensions = {
    LoadBalancer = aws_lb.web_alb.arn_suffix
  }

  tags = {
    Service = "ALB"
    Purpose = "ErrorMonitoring"
  }
}

# EventBridge Rules 

# SecurityHub findings (filtered)
resource "aws_cloudwatch_event_rule" "sechub_findings" {
  name        = "sechub-findings"
  description = "Route only MEDIUM+ SecurityHub findings to SOAR Lambda"
  event_pattern = jsonencode({
    "source": ["aws.securityhub"],
    "detail-type": ["Security Hub Findings - Imported"],
    "detail": {
      "findings": {
        "Severity": {
          "Label": ["MEDIUM", "HIGH", "CRITICAL"]
        }
      }
    }
  })

  tags = { Source = "SecurityHub" }
}

resource "aws_cloudwatch_event_target" "sechub_to_soar" {
  rule       = aws_cloudwatch_event_rule.sechub_findings.name
  arn        = aws_lambda_function.soar.arn
  depends_on = [aws_lambda_function.soar]
}

# GuardDuty findings
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  name        = "guardduty-findings"
  description = "Route GuardDuty findings to SOAR Lambda"
  event_pattern = jsonencode({
    "source": ["aws.guardduty"],
    "detail-type": ["GuardDuty Finding"]
  })
  tags = { Source = "GuardDuty" }
}

resource "aws_cloudwatch_event_target" "gd_to_soar" {
  rule       = aws_cloudwatch_event_rule.guardduty_findings.name
  arn        = aws_lambda_function.soar.arn
  depends_on = [aws_lambda_function.soar]
}

# CloudWatch alarm state changes
resource "aws_cloudwatch_event_rule" "cw_alarm_state" {
  name        = "cw-alarm-state"
  description = "Send CloudWatch alarm state changes to SOAR Lambda"
  event_pattern = jsonencode({
    "source": ["aws.cloudwatch"],
    "detail-type": ["CloudWatch Alarm State Change"]
  })
  tags = { Source = "CloudWatch" }
}

resource "aws_cloudwatch_event_target" "cw_to_soar" {
  rule       = aws_cloudwatch_event_rule.cw_alarm_state.name
  arn        = aws_lambda_function.soar.arn
  depends_on = [aws_lambda_function.soar]
}

# Lambda Permissions
resource "aws_lambda_permission" "allow_eventbridge_invoke" {
  for_each = {
    sechub = aws_cloudwatch_event_rule.sechub_findings.arn
    gd     = aws_cloudwatch_event_rule.guardduty_findings.arn
    cw     = aws_cloudwatch_event_rule.cw_alarm_state.arn
  }

  statement_id  = "AllowEventBridgeInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soar.function_name
  principal     = "events.amazonaws.com"
  source_arn    = each.value
}

# SOAR Test Trigger (manual event)
resource "aws_cloudwatch_event_rule" "soar_test_trigger" {
  name        = "soar-test-trigger"
  description = "Manual test event for SOAR pipeline"
  event_pattern = jsonencode({
    "source": ["custom.soar-test"],
    "detail-type": ["SOAR Test Event"]  
  })

  tags = { Source = "ManualTest" }
}

resource "aws_cloudwatch_event_target" "soar_test_to_lambda" {
  rule       = aws_cloudwatch_event_rule.soar_test_trigger.name
  arn        = aws_lambda_function.soar.arn
  depends_on = [aws_lambda_function.soar]
}

# Allow EventBridge to invoke SOAR Lambda for the test rule
resource "aws_lambda_permission" "allow_test_invoke" {
  statement_id  = "AllowEventBridgeInvokeSOARTest"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soar.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.soar_test_trigger.arn
}

# WebApp Brute Force Detection 
resource "aws_cloudwatch_event_rule" "webapp_bruteforce" {
  name         = "webapp-bruteforce"
  description  = "Triggers SOAR when the webapp detects multiple failed logins"
  event_pattern = jsonencode({
    "source": ["custom.webapp"],
    "detail-type": ["BruteForce Login Alert"]
  })
  tags = { Source = "WebApp" }
}

resource "aws_cloudwatch_event_target" "webapp_to_soar" {
  rule       = aws_cloudwatch_event_rule.webapp_bruteforce.name
  arn        = aws_lambda_function.soar.arn
  depends_on = [aws_lambda_function.soar]
}

# Allow EventBridge to invoke SOAR for this new rule
resource "aws_lambda_permission" "allow_webapp_invoke" {
  statement_id  = "AllowEventBridgeInvokeWebApp"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.soar.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.webapp_bruteforce.arn
}
