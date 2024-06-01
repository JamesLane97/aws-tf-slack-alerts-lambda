# Terraform Configuration & Python Lambda for Monitoring AWS RDS and ECS Resources with Alerts Sent to Slack via SNS

This repository contains Terraform configurations and a Python Lambda function designed to monitor AWS RDS and ECS resources. Alerts are sent to Slack via SNS for real-time notifications.

## Overview

This project utilizes Terraform to configure AWS resources and a Python Lambda function to monitor AWS RDS and ECS services. When specified events or metrics thresholds are met, alerts are triggered and sent to a Slack channel via Amazon SNS.

## Architecture

The architecture of this project includes:
- AWS RDS and ECS services
- CloudWatch Alarms for monitoring specific metrics
- SNS topics for alert notifications
- Lambda function to handle SNS messages and forward them to Slack

## Terraform Configuration

The Terraform configuration in this repository sets up the necessary AWS resources, including RDS and ECS monitoring, CloudWatch alarms, SNS topics, and the Lambda function.

### `variables.tf`

Defines the variables used in the Terraform configuration.

### `data.tf`

Fetches necessary data from AWS, such as region and caller identity.

### `main.tf`

Contains the main Terraform configuration for setting up resources and monitoring.

## Python Lambda Function

The Python Lambda function processes SNS messages and sends alerts to a Slack channel. The source code for the Lambda function is in `infra_alerts_to_slack.py`.

### Environment Variables

The Lambda function requires the following environment variables:

-   `SLACK_WEBHOOK_URL`: The webhook URL to send messages to Slack.

## Variables

-   `resource_prefix`: Prefix for all resources
-   `name`: Name of all resources
-   `lambda_filename`: Filename of the Lambda function (default: `"lambda.js"`)
-   `lambda_handler`: Lambda handler (default: `"lambda.handler"`)
-   `lambda_runtime`: Lambda runtime (default: `"nodejs18.x"`)
-   `lambda_architectures`: Lambda architectures (default: `["arm64"]`)
-   `lambda_memory_size`: Lambda memory size (default: `128`)
-   `lambda_timeout`: Lambda timeout in seconds (default: `10`)
-   `lambda_env_vars`: Lambda environment variables (default: `{}`)
-   `elasticache_member_clusters`: List of Cluster IDs (default: `[]`)
-   `rds_serverlessv2_max_capacity`: Serverless v2 max ACU capacity (default: `null`)
-   `p1_alerts_email_subscribers`: Email address subscribers for P1 alerts (default: `[]`)
