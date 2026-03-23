data "archive_file" "lambda" {
    type        = "zip"
    source_dir  = "${path.module}/../../lambda/validate_deployment"
    output_path = "${path.module}/../../lambda/validate_deployment.zip"
  }

  resource "aws_iam_role" "lambda" {
    name = "validate-deployment-lambda-role"

    assume_role_policy = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect    = "Allow"
        Principal = { Service = "lambda.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }]
    })
  }

  resource "aws_iam_role_policy" "lambda" {
    name = "validate-deployment-lambda-policy"
    role = aws_iam_role.lambda.id

    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow"
          Action = [
            "ecs:DescribeServices",
            "ecs:ListTasks",
            "ecs:DescribeTasks"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "codedeploy:PutLifecycleEventHookExecutionStatus"
          ]
          Resource = "*"
        },
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "*"
        }
      ]
    })
  }

  resource "aws_lambda_function" "validate_deployment" {
    filename         = data.archive_file.lambda.output_path
    function_name    = "validate-deployment"
    role             = aws_iam_role.lambda.arn
    handler          = "handler.handler"
    runtime          = "python3.11"
    timeout          = 60
    source_code_hash = data.archive_file.lambda.output_base64sha256
  }