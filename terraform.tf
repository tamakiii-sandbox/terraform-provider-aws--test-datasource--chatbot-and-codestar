terraform {
  backend "s3" {
    # Backend configuration is provided via `state.config`.
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.98.0"
    }
  }
}
