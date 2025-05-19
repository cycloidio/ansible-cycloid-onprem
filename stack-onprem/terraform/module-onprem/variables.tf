data "aws_region" "current" {}

variable "bastion_sg_allow" {
}

variable "project" {
  default = "onprem"
}

variable "env" {}
variable "customer" {}
variable "component" {}

variable "extra_tags" {
  default = {}
}

locals {
  standard_tags = {
    "cycloid.io" = "true"
    env          = var.env
    project      = var.project
    client       = var.customer
    component    = var.component
  }
  merged_tags = merge(local.standard_tags, var.extra_tags)
}

variable "keypair_name" {
  default = "cycloid"
}

variable "public_subnets_ids" {
  type = list(string)
}

variable "vpc_id" {
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Example ["eu-west-1a", "eu-west-1b", "eu-west-1c"]
variable "zones" {
  description = "To use specific AWS Availability Zones."
  default     = []
}

locals {
  aws_availability_zones = length(var.zones) > 0 ? var.zones : data.aws_availability_zones.available.names
}

variable "base_ami_id" {
  default = ""
}

variable "debian_ami_name" {
  default = "debian-stretch-*"
}
