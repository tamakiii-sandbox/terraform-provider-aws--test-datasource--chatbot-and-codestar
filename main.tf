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
