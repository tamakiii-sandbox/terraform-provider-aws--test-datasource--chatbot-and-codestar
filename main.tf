provider "aws" {
  region = "ap-northeast-1"
}

variable "identifier" {
  type    = string
  default = "TestDatasourceChatbotAndCodestar"
}

variable "s3_codepipeline_artifact_bucket" {
  type = string
}

variable "github_repository" {
  type = string
}

variable "slack_team_name" {
  type = string
}

variable "slack_channel_id" {
  type = string
}

data "aws_s3_bucket" "codepipeline_artifact" {
  bucket = var.s3_codepipeline_artifact_bucket
}

resource "aws_cloudwatch_log_group" "codebuild_build" {
  name = "/aws/codebuild/${var.identifier}-Build"
}

resource "aws_iam_role" "chatbot" {
  name               = "${var.identifier}-ChatBot"
  assume_role_policy = data.aws_iam_policy_document.chatbot_assume_role_policy.json

  tags = {
    Service = var.identifier
  }
}

data "aws_iam_policy_document" "chatbot_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["chatbot.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "codepipeline" {
  name               = "${var.identifier}-CodePipeline"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role_policy.json

  tags = {
    Service = var.identifier
  }
}

data "aws_iam_policy_document" "codepipeline_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["codepipeline.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codepipeline" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObject",
    ]
    resources = [
      "${data.aws_s3_bucket.codepipeline_artifact.arn}",
      "${data.aws_s3_bucket.codepipeline_artifact.arn}/*",
    ]
  }

  statement {
    actions = [
      "codebuild:BatchGetBuilds",
      "codebuild:StartBuild"
    ]
    resources = [
      aws_codebuild_project.build.arn,
    ]
  }

  statement {
    actions = [
      "codestar-connections:UseConnection"
    ]
    resources = [
      aws_codestarconnections_connection.github.arn
    ]
  }
}

resource "aws_iam_policy" "codepipeline" {
  name   = "${var.identifier}-CodePipeline"
  policy = data.aws_iam_policy_document.codepipeline.json
}

resource "aws_iam_role_policy_attachment" "codepipeline" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.codepipeline.arn
}

resource "aws_iam_role" "codebuild" {
  name               = "${var.identifier}-CodeBuild"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role_policy.json

  tags = {
    Service = var.identifier
  }
}

data "aws_iam_policy_document" "codebuild_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["codebuild.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "codebuild" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "${aws_cloudwatch_log_group.codebuild_build.arn}",
      "${aws_cloudwatch_log_group.codebuild_build.arn}:*",
    ]
  }

  statement {
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetBucketVersioning",
      "s3:PutObject",
    ]
    resources = [
      "${data.aws_s3_bucket.codepipeline_artifact.arn}",
      "${data.aws_s3_bucket.codepipeline_artifact.arn}/*",
    ]
  }
}

resource "aws_iam_policy" "codebuild" {
  name   = "${var.identifier}-CodeBuild"
  policy = data.aws_iam_policy_document.codebuild.json
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  role       = aws_iam_role.codebuild.name
  policy_arn = aws_iam_policy.codebuild.arn
}

resource "aws_codebuild_project" "build" {
  name          = "${var.identifier}-Build"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = "5"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    type            = "ARM_CONTAINER"
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux-aarch64-standard:3.0"
    privileged_mode = false
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = <<EOF
version: 0.2
phases:
  build:
    commands:
      - echo "Hello, its $(date --rfc-3339=ns) here." | tee info.txt
      - cat /etc/os-release | tee -a info.txt
      - uname -a | tee -a info.txt
artifacts:
  files:
    - info.txt
  discard-paths: yes
EOF
  }

  tags = {
    Service = var.identifier
  }
}

// NOTE: You’ll need to replace this resource after the initial connection.
resource "aws_codestarconnections_connection" "github" {
  name          = var.identifier
  provider_type = "GitHub"

  tags = {
    Service = var.identifier
  }
}

data "aws_chatbot_slack_workspace" "workspace" {
  slack_team_name = var.slack_team_name
}

resource "aws_chatbot_slack_channel_configuration" "channel" {
  configuration_name = "${var.identifier}-Test"
  iam_role_arn       = aws_iam_role.chatbot.arn
  slack_channel_id   = var.slack_channel_id
  slack_team_id      = data.aws_chatbot_slack_workspace.workspace.slack_team_id

  tags = {
    Service = var.identifier
  }
}

resource "aws_codestarnotifications_notification_rule" "codebuild" {
  name        = "${var.identifier}-CodeBuild"
  detail_type = "BASIC"
  event_type_ids = [
    "codebuild-project-build-phase-failure",
    "codebuild-project-build-phase-success",
    "codebuild-project-build-state-failed",
    "codebuild-project-build-state-in-progress",
    "codebuild-project-build-state-stopped",
    "codebuild-project-build-state-succeeded",
  ]

  resource = aws_codebuild_project.build.arn

  target {
    type    = "AWSChatbotSlack"
    address = aws_chatbot_slack_channel_configuration.channel.chat_configuration_arn
  }

  tags = {
    Service = var.identifier
  }
}

resource "aws_codepipeline" "pipeline" {
  name          = "${var.identifier}-Pipeline"
  pipeline_type = "V2"
  role_arn      = aws_iam_role.codepipeline.arn

  artifact_store {
    location = data.aws_s3_bucket.codepipeline_artifact.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn        = aws_codestarconnections_connection.github.arn
        FullRepositoryId     = var.github_repository
        BranchName           = "main"
        OutputArtifactFormat = "CODE_ZIP"
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  tags = {
    Service = var.identifier
  }
}
