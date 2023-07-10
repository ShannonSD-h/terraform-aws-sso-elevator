module "access_revoker" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "4.16.0"

  function_name = var.revoker_lambda_name
  description   = "Revokes temporary permissions"
  handler       = "revoker.lambda_handler"
  publish       = true
  timeout       = 300

  depends_on = [null_resource.python_version_check]
  hash_extra = var.revoker_lambda_name

  build_in_docker = var.build_in_docker
  runtime         = "python${local.python_version}"
  docker_image    = "lambda/python:${local.python_version}"
  docker_file     = "${path.module}/src/docker/Dockerfile"
  source_path = [
    {
      path           = "${path.module}/src/"
      poetry_install = true
      artifacts_dir  = "${path.root}/builds/"
      patterns = [
        "!.venv/.*",
        "!.vscode/.*",
        "!__pycache__/.*",
        "!tests/.*",
      ]
    }
  ]

  environment_variables = {
    LOG_LEVEL = var.log_level

    SLACK_SIGNING_SECRET = var.slack_signing_secret
    SLACK_BOT_TOKEN      = var.slack_bot_token
    SLACK_CHANNEL_ID     = var.slack_channel_id
    SCHEDULE_GROUP_NAME  = var.schedule_group_name

    SSO_INSTANCE_ARN            = local.sso_instance_arn
    STATEMENTS                  = jsonencode(var.config)
    POWERTOOLS_LOGGER_LOG_EVENT = true

    POST_UPDATE_TO_SLACK                        = var.revoker_post_update_to_slack
    SCHEDULE_POLICY_ARN                         = aws_iam_role.eventbridge_role.arn
    REVOKER_FUNCTION_ARN                        = local.revoker_lambda_arn
    REVOKER_FUNCTION_NAME                       = var.revoker_lambda_name
    S3_BUCKET_FOR_AUDIT_ENTRY_NAME              = local.s3_bucket_name
    S3_BUCKET_PREFIX_FOR_PARTITIONS             = var.s3_bucket_partition_prefix
    SSO_ELEVATOR_SCHEDULED_REVOCATION_RULE_NAME = aws_cloudwatch_event_rule.sso_elevator_scheduled_revocation.name
    REQUEST_EXPIRATION_HOURS                    = var.request_expiration_hours

    APPROVER_RENOTIFICATION_INITIAL_WAIT_TIME  = var.approver_renotification_initial_wait_time
    APPROVER_RENOTIFICATION_BACKOFF_MULTIPLIER = var.approver_renotification_backoff_multiplier
  }

  allowed_triggers = {
    cron = {
      principal  = "events.amazonaws.com"
      source_arn = aws_cloudwatch_event_rule.sso_elevator_scheduled_revocation.arn
    }
    check_inconsistency = {
      principal  = "events.amazonaws.com"
      source_arn = aws_cloudwatch_event_rule.sso_elevator_check_on_inconsistency.arn
    }
  }

  attach_policy_json = true
  policy_json        = data.aws_iam_policy_document.revoker.json

  dead_letter_target_arn    = aws_sns_topic.dlq.arn
  attach_dead_letter_policy = true

  # do not retry automatically
  maximum_retry_attempts = 0

  cloudwatch_logs_retention_in_days = 365

  layers = [
    module.sso_elevator_dependencies.lambda_layer_arn,
  ]

  tags = var.tags
}

data "aws_iam_policy_document" "revoker" {
  statement {
    sid    = "AllowDescribeRule"
    effect = "Allow"
    actions = [
      "events:DescribeRule"
    ]
    resources = [
      "arn:aws:events:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:rule/${var.event_brige_scheduled_revocation_rule_name}"
    ]
  }
  statement {
    sid    = "AllowListSSOInstances"
    effect = "Allow"
    actions = [
      "sso:ListInstances"
    ]
    resources = ["*"]
  }
  statement {
    sid    = "AllowSSO"
    effect = "Allow"
    actions = [
      "sso:ListAccountAssignments",
      "sso:DeleteAccountAssignment",
      "sso:DescribeAccountAssignmentDeletionStatus"
    ]
    resources = [
      "arn:aws:sso:::instance/*",
      "arn:aws:sso:::permissionSet/*/*",
      "arn:aws:sso:::account/*"
    ]
  }
  statement {
    effect = "Allow"
    actions = [
      "organizations:ListAccounts",
      "organizations:DescribeAccount",
      "sso:ListPermissionSets",
      "sso:DescribePermissionSet",
      "identitystore:ListUsers",
      "identitystore:DescribeUser",
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "scheduler:DeleteSchedule",
      "scheduler:CreateSchedule",
      "scheduler:ListSchedules",
      "scheduler:GetSchedule",
    ]
    resources = ["*"]
  }
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
    ]
    resources = ["${local.s3_bucket_arn}/${var.s3_bucket_partition_prefix}/*"]
  }
}

resource "aws_cloudwatch_event_rule" "sso_elevator_scheduled_revocation" {
  name                = var.event_brige_scheduled_revocation_rule_name
  description         = "Triggers on schedule to revoke temporary permissions."
  schedule_expression = var.schedule_expression
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "sso_elevator_scheduled_revocation" {
  rule = aws_cloudwatch_event_rule.sso_elevator_scheduled_revocation.name
  arn  = module.access_revoker.lambda_function_arn
  input = jsonencode({
    "action" : "sso_elevator_scheduled_revocation"
  })
}

resource "aws_cloudwatch_event_rule" "sso_elevator_check_on_inconsistency" {
  name                = var.event_brige_check_on_inconsistency_rule_name
  description         = "Triggers on schedule to check on inconsistency."
  schedule_expression = var.schedule_expression_for_check_on_inconsistency
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "check_inconsistency" {
  rule = aws_cloudwatch_event_rule.sso_elevator_check_on_inconsistency.name
  arn  = module.access_revoker.lambda_function_arn
  input = jsonencode({
    "action" : "check_on_inconsistency"
  })
}

resource "aws_iam_role" "eventbridge_role" {
  name = var.schedule_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "scheduler.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_policy" {
  name = "eventbridge_policy_for_sso_elevator"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "events:PutRule",
          "events:PutTargets"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      {
        Action = [
          "lambda:InvokeFunction"
        ]
        Effect   = "Allow"
        Resource = module.access_revoker.lambda_function_arn
      }
    ]
  })

  role = aws_iam_role.eventbridge_role.id
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = module.access_revoker.lambda_function_name
  principal     = "scheduler.amazonaws.com"
  source_arn    = aws_iam_role.eventbridge_role.arn
}
