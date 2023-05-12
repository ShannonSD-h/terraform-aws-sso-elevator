variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}

variable "aws_sns_topic_subscription_email" {
  description = "value for the email address to subscribe to the SNS topic"
  type        = string
}

variable "slack_signing_secret" {
  description = "value for the Slack signing secret"
  type        = string
}

variable "slack_bot_token" {
  description = "value for the Slack bot token"
  type        = string
}

variable "log_level" {
  description = "value for the log level"
  type        = string
  default     = "INFO"
}

variable "slack_channel_id" {
  description = "value for the Slack channel ID"
  type        = string
}

variable "schedule_expression" {
  description = "recovation schedule expression (will revoke all user-level assignments unknown to the Elevator)"
  type        = string
  default     = "cron(0 23 * * ? *)"
}

variable "schedule_expression_for_check_on_inconsistency" {
  description = "how often revoker should check for inconsistency (warn if found unknown user-level assignments)"
  type        = string
  default     = "rate(2 hours)"
}

variable "sso_instance_arn" {
  description = "value for the SSO instance ARN"
  type        = string
  default     = ""
}

variable "config" {
  description = "value for the SSO Elevator config"
  type        = any
}

variable "revoker_lambda_name" {
  description = "value for the revoker lambda name"
  type        = string
  default     = "access-revoker"
}

variable "requester_lambda_name" {
  description = "value for the requester lambda name"
  type        = string
  default     = "access-requester"
}

variable "revoker_lambda_name_postfix" {
  description = "For dev purposes"
  type        = string
  default     = ""
}

variable "requester_lambda_name_postfix" {
  description = "For dev purposes"
  type        = string
  default     = ""
}

variable "schedule_group_name_postfix" {
  description = "For dev purposes"
  type        = string
  default     = ""
}

variable "schedule_role_name_postfix" {
  description = "For dev purposes"
  type        = string
  default     = ""
}

variable "s3_bucket_name_postfix" {
  description = "For dev purposes"
  type        = string
  default     = ""
}
variable "revoker_post_update_to_slack" {
  description = "Should revoker send a confirmation of the revocation to Slack?"
  type        = bool
  default     = true
}

variable "build_in_docker" {
  description = "Whether to build the lambda in a docker container or using local python (poetry)"
  type        = bool
  default     = true
}

variable "s3_bucket_for_audit_entry_name" {
  description = "Name of the S3 bucket"
  type        = string
  default     = "sso-elevator-logs"
}

variable "s3_bucket_prefix_for_partitions" {
  description = "The prefix for the S3 bucket partitions"
  type        = string
  default     = "logs"
}

variable "name_of_existing_s3_bucket" {
  description = "Pass it if you want to use an existing bucket"
  type        = string
  default     = ""
}

variable "object_lock_for_s3_bucket" {
  description = "Enable object lock"
  type        = bool
  default     = false
}

variable "name_of_logging_bucket_for_s3" {
  description = "Bucket for storing s3 logs"
  type        = string
  default     = ""
}
variable "mfa_delete" {
  description = "Whether to enable MFA delete for the S3 bucket"
  type        = bool
  default     = false 
}

