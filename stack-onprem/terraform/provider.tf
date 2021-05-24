provider "aws" {
  access_key = var.access_key
  secret_key = var.secret_key
  region     = var.aws_region
}

variable "customer" {
}

variable "project" {
}

variable "env" {
}

variable "access_key" {
}

variable "secret_key" {
}

variable "aws_region" {
  description = "AWS region to launch servers."
  default     = "eu-west-1"
}

# Fixed value until we can add it into forms. Allow us to get output from infra project
data "terraform_remote_state" "infrastructure" {
  backend = "s3"

  config = {
    bucket = "cycloid-terraform-remote-state"
    key    = "infrastructure/infra/infrastructure-infra.tfstate"
    region = "eu-west-1"
  }
}
