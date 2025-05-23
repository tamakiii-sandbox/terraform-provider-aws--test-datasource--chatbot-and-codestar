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
