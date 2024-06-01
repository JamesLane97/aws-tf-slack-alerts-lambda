locals {
  name_slack        = "${var.resource_prefix}-${var.name}-to-slack-${terraform.workspace}"
  name_email        = "${var.resource_prefix}-${var.name}-p1-to-email-${terraform.workspace}"
  db_instances      = length(data.aws_db_instances.this.instance_identifiers) > 0 ? data.aws_db_instances.this.instance_identifiers : []
  alb_arns          = length(data.aws_lbs.this.arns) > 0 ? data.aws_lbs.this.arns : []
  alb_stripped_arns = [for arn in local.alb_arns : join("/", slice(split("/", arn), index(split("/", arn), "app"), length(split("/", arn))))]
}

/*
========================================================================================
=====================================RDS Monitoring=====================================
========================================================================================
*/
# RDS DB Event Subscription
resource "aws_db_event_subscription" "rds_alerts" {
  name        = local.name_slack
  sns_topic   = aws_sns_topic.slack_alerts.arn
  source_type = "db-instance"

  event_categories = [
    "deletion",
    "availability",
    "low storage",
    "restoration",
    "failover",
    "failure",
    "notification",
    "recovery",
    "backtrack"
  ]
}

/*
========================================================================================
=========================================ALARMS=========================================
========================================================================================
*/

/*
========
===P1===
========
*/

# CloudWatch Alarm: ALB - 500 Errors for each ALB (P1)
resource "aws_cloudwatch_metric_alarm" "alb_500_errors_alarm" {
  for_each                  = { for idx, stripped_arn in local.alb_stripped_arns : idx => stripped_arn }
  alarm_name                = "ALB-5XX-Errors-Alarm-${each.value}"
  alarm_description         = "Alarm when 80% of requests result in 5xx errors"
  comparison_operator       = "GreaterThanOrEqualToThreshold"
  evaluation_periods        = 2
  threshold                 = 80
  insufficient_data_actions = []

  metric_query {
    id          = "e1"
    expression  = "m2/m1*100"
    label       = "ELB 5xx Error Rate"
    return_data = "true"
  }

  metric_query {
    id = "m1"

    metric {
      metric_name = "RequestCount"
      namespace   = "AWS/ApplicationELB"
      period      = 120
      stat        = "Sum"
      unit        = "Count"

      dimensions = {
        LoadBalancer = each.value
      }
    }
  }

  metric_query {
    id = "m2"

    metric {
      metric_name = "HTTPCode_ELB_5XX_Count"
      namespace   = "AWS/ApplicationELB"
      period      = 120
      stat        = "Sum"
      unit        = "Count"

      dimensions = {
        LoadBalancer = each.value
      }
    }
  }

  alarm_actions = compact([
    aws_sns_topic.slack_alerts.arn,
    try(aws_sns_topic.p1_email_alerts[0].arn, null)
  ])
}

# CloudWatch Alarm: ElastiCache - Database Memory Usage (P1)
resource "aws_cloudwatch_metric_alarm" "elasticache_memory_alarm" {
  alarm_name          = "ElastiCache-Memory-Usage-Alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"

  alarm_description = "Alarm when ElastiCache Database Memory Usage is above 80%"

  alarm_actions = compact([
    aws_sns_topic.slack_alerts.arn,
    try(aws_sns_topic.p1_email_alerts[0].arn, null)
  ])
}

# CloudWatch Alarm: ElastiCache Cluster - CurrConnections == 0 (P1)
resource "aws_cloudwatch_metric_alarm" "elasticache_curr_items_alarm" {
  count               = length(var.elasticache_member_clusters)
  alarm_name          = "ElastiCache-Cluster-CurrConnections-Equals-Zero-Alarm-${var.elasticache_member_clusters[count.index]}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 2
  threshold           = 1
  alarm_description   = "Alarm for CurrConnections reaching zero on ElastiCache cluster ${var.elasticache_member_clusters[count.index]}"

  metric_query {
    id          = "e1"
    expression  = "IF(m1 == 0, 1, 0)"
    label       = "CurrConnections == 0"
    return_data = "true"
  }

  metric_query {
    id = "m1"

    metric {
      metric_name = "CurrConnections"
      namespace   = "AWS/ElastiCache"
      period      = 120
      stat        = "Maximum"
      unit        = "Count"

      dimensions = {
        CacheClusterId = var.elasticache_member_clusters[count.index]
      }
    }
  }

  alarm_actions = compact([
    aws_sns_topic.slack_alerts.arn,
    try(aws_sns_topic.p1_email_alerts[0].arn, null)
  ])
}

/*
========
===P2===
========
*/

# CloudWatch Alarm: ElastiCache - Cache CPU > 80% (P2)
resource "aws_cloudwatch_metric_alarm" "cache_cpu_alarm" {
  alarm_name          = "ElastiCache-High-CPU-Utilisation-Alarm"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"

  alarm_actions = [
    aws_sns_topic.slack_alerts.arn
  ]

  treat_missing_data = "notBreaching"
}

# CloudWatch Alarm: RDS - CPU Util >= 90% (P2)
resource "aws_cloudwatch_metric_alarm" "rds_cpu_alarm" {
  count               = length(local.db_instances)
  alarm_name          = "RDS-High-CPU-Utilisation-Alarm-${local.db_instances[count.index]}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 300
  statistic           = "Average"
  threshold           = 90
  alarm_description   = "Alarm when RDS CPU Utilisation exceeds 90%"

  dimensions = {
    DBInstanceIdentifier = local.db_instances[count.index]
  }

  alarm_actions = [
    aws_sns_topic.slack_alerts.arn
  ]
}

#Cloud Watch Alarm: RDS ServerlessDatabaseCapacity >= rds_serverlessv2_max_capacity (P2)
resource "aws_cloudwatch_metric_alarm" "rds_capacity_alarm" {
  count = length(data.aws_db_instances.this.instance_identifiers)

  alarm_name          = "RDS-Exceeds-Capacity-Alarm-${local.db_instances[count.index]}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2"
  metric_name         = "ServerlessDatabaseCapacity"
  namespace           = "AWS/RDS"
  period              = "300"
  threshold           = var.rds_serverlessv2_max_capacity
  statistic           = "Maximum"
  alarm_description   = "Alarm when RDS Serverless Database Capacity exceeds ${var.rds_serverlessv2_max_capacity} ACUs"

  dimensions = {
    DBClusterIdentifier = local.db_instances[count.index]
  }

  alarm_actions = [
    aws_sns_topic.slack_alerts.arn,
  ]

  treat_missing_data = "notBreaching"
}

/*
========================================================================================
======================================SNS to Slack======================================
========================================================================================
*/

#Slack SNS Config
resource "aws_sns_topic" "slack_alerts" {
  name = local.name_slack
}

resource "aws_sns_topic_policy" "slack_alerts" {
  arn    = aws_sns_topic.slack_alerts.arn
  policy = data.aws_iam_policy_document.slack_alerts_sns_topic_policy.json
}

data "aws_iam_policy_document" "slack_alerts_sns_topic_policy" {
  policy_id = "__default_policy_ID"
  statement {
    actions = [
      "SNS:Publish"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.rds.amazonaws.com"]
    }
    resources = [aws_sns_topic.slack_alerts.arn]
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:aws:rds:${data.aws_region.this.name}:${data.aws_caller_identity.current.id}:db:*",
      ]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values = [
        "${data.aws_caller_identity.current.id}",
      ]
    }
    sid = "__default_statement_ID"
  }
  statement {
    actions = [
      "SNS:Publish"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    resources = [aws_sns_topic.slack_alerts.arn]
    sid       = "__cloudwatch_statement_ID"
  }

  statement {
    actions = [
      "SNS:Publish"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    resources = [aws_sns_topic.slack_alerts.arn]
    sid       = "__eventbridge_statement_ID"
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        aws_cloudwatch_event_rule.ecs_events_rule.arn,
      ]
    }
  }
}

resource "aws_sns_topic_subscription" "slack_alerts" {
  topic_arn = aws_sns_topic.slack_alerts.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.slack_alerts_lambda.arn
}

# SNS to slack lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.name_slack}"
  retention_in_days = 14
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam-lambda-${local.name_slack}"

  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "lambda.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_policy" "lambda_logging" {
  name        = "lambda-logging-${local.name_slack}"
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": [
        "arn:aws:logs:${data.aws_region.this.name}:${data.aws_caller_identity.current.account_id}:log-group:${aws_cloudwatch_log_group.lambda.name}:*"
        ],
     "Effect": "Allow"
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_logging.arn
}

resource "aws_lambda_function" "slack_alerts_lambda" {
  function_name    = local.name_slack
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  handler          = var.lambda_handler
  runtime          = var.lambda_runtime
  role             = aws_iam_role.iam_for_lambda.arn
  memory_size      = var.lambda_memory_size
  timeout          = var.lambda_timeout
  architectures    = var.lambda_architectures
  environment {
    variables = var.lambda_env_vars
  }
  depends_on = [
    aws_iam_role_policy_attachment.lambda_logs,
    aws_cloudwatch_log_group.lambda,
  ]
}

resource "aws_lambda_permission" "sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.slack_alerts_lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.slack_alerts.arn
}

/*
========================================================================================
====================================SNS to P1 Email=====================================
========================================================================================
*/

# P1 email SNS Config
resource "aws_sns_topic" "p1_email_alerts" {
  count = length(var.p1_alerts_email_subscribers) > 0 ? 1 : 0
  name  = local.name_email
}

resource "aws_sns_topic_policy" "p1_email_alerts" {
  count  = length(var.p1_alerts_email_subscribers) > 0 ? 1 : 0
  arn    = aws_sns_topic.p1_email_alerts[0].arn
  policy = data.aws_iam_policy_document.p1_email_alerts_sns_topic_policy[0].json
}

data "aws_iam_policy_document" "p1_email_alerts_sns_topic_policy" {
  count     = length(var.p1_alerts_email_subscribers) > 0 ? 1 : 0
  policy_id = "__default_policy_ID"
  statement {
    actions = [
      "SNS:Publish"
    ]
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com"]
    }
    resources = [aws_sns_topic.p1_email_alerts[0].arn]
    sid       = "__cloudwatch_statement_ID"
  }
}

resource "aws_sns_topic_subscription" "p1_email_alerts" {
  count     = length(var.p1_alerts_email_subscribers)
  topic_arn = aws_sns_topic.p1_email_alerts[0].arn
  protocol  = "email"
  endpoint  = var.p1_alerts_email_subscribers[count.index]
}


/*
========================================================================================
====================================ECS Monitoring=====================================
========================================================================================
*/

# EventBridge rule to filter ECS service action events of type WARN and ERROR
resource "aws_cloudwatch_event_rule" "ecs_events_rule" {
  name        = "ecs_events_rule"
  description = "Event rule for ECS service action events"
  event_pattern = <<PATTERN
{
  "source": ["aws.ecs"],
  "detail-type":["ECS Service Action"],
  "detail": {
    "eventType": ["WARN", "ERROR"]
  }
}
PATTERN
}

# Add Lambda as a target for the EventBridge rule
resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.ecs_events_rule.name
  target_id = "sns_target"
  arn       = aws_sns_topic.slack_alerts.arn
}
