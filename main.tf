provider "aws" {
  region = "ap-northeast-1"
}

variable "identifier" {
  type    = string
  default = "TestDatasourceChatbotAndCodestar"
}

variable "s3_codepipeline_artifact_arn" {
  type = string
}

data "aws_s3_bucket" "codepipeline_artifact" {
  bucket = var.s3_codepipeline_artifact_arn
}

resource "aws_iam_role" "codepipeline" {
  name               = "${var.identifier}-CodePipeline"
  assume_role_policy = data.aws_iam_policy_document.codepipeline_assume_role_policy.json

  tags = {
    Name = var.identifier
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
      "*" // TODO: fix me
    ]
  }
}

resource "aws_iam_policy" "codepipeline" {
  name        = "${var.identifier}-CodePipeline"
  policy      = data.aws_iam_policy_document.codepipeline.json
}

resource "aws_iam_role_policy_attachment" "codepipeline" {
  role       = aws_iam_role.codepipeline.name
  policy_arn = aws_iam_policy.codepipeline.arn
}

resource "aws_iam_role" "codebuild" {
  name = "${var.identifier}-CodeBuild"
  assume_role_policy = data.aws_iam_policy_document.codebuild_assume_role_policy.json
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
      "*"
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
  name        = "${var.identifier}-CodeBuild"
  policy      = data.aws_iam_policy_document.codebuild.json
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
}

resource "aws_codepipeline" "pipeline" {
  name = "${var.identifier}-Pipeline"
  pipeline_type = "V2"
  role_arn = aws_iam_role.codepipeline.arn

  artifact_store {
    location = data.aws_s3_bucket.codepipeline_artifact.arn
    type = "S3"
  }

  stage {
    name = "Build"

    action {
      name = "Build"

      action {
        name = "Build"
        category = "Build"
        owner = "AWS"
        provider = "CodeBuild"
        version = "1"

        configuration = {
          ProjectName = aws_codebuild_project.build.name
        }
      }
    }
  }
}
