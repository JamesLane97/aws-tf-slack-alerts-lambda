data "aws_region" "this" {}

data "aws_caller_identity" "current" {}

data "aws_db_instances" "this" {}

data "aws_lbs" "this" {}

data "archive_file" "lambda" {
  type        = "zip"
  output_path = "/sources/build/${local.name_slack}-lambda.zip"
  source {
    content  = file("/sources/${var.lambda_filename}")
    filename = var.lambda_filename
  }
}