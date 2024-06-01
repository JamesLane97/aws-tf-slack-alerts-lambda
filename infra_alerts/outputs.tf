output "sns_arn" {
  description = "ARN of the SNS topic"
  value       = aws_sns_topic.slack_alerts.arn
}

 output "ecs_events_rule_arn" {
  description = "ARN of the ECS rule topic"
  value = aws_cloudwatch_event_rule.ecs_events_rule.arn
}