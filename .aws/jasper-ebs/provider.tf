terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }

  backend "s3" {
    region  = "ap-south-1"
    bucket  = "u2-megha-backend-infra"
    key     = "ec2/dev/jasper-report/terraform.tfstate"
  } 
}

provider "aws" {
  region = var.region
}
