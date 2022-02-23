data "aws_region" "current" {}

variable "bastion_sg_allow" {
}

variable "project" {
  default = "onprem"
}

variable "env" {
}

variable "customer" {
}

variable "extra_tags" {
  default = {}
}

locals {
  standard_tags = {
    "cycloid.io" = "true"
    env          = var.env
    project      = var.project
    client       = var.customer
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

###
# AMI DATA
###
variable "ami_most_recent" {
  description = "If more than one result is returned, use the most recent AMI."
  default     = true
}

variable "ami_name" {
  description = "The name of the AMI (provided during image creation)."
  default     = "debian-stretch-*"
}


variable "sg_ingress_rules" {
  description = "Configuration block for ingress rules."
  default = [
    {
      description      = "Accept ssh traffic"
      from_port        = 22
      to_port          = 22
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = true
    },
    {
      description      = "Accept Elasticsearch traffic"
      from_port        = 9200
      to_port          = 9200
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = true
    }
  ]
}

variable "sg_egress_rules" {
  description = "Configuration block for egress rules."
  default = [
    {
      description      = "Accept all egress"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = true
    }
  ]
}

variable "sg_extra_tags" {
  description = "Map of extra tags to assign to the security group."
  default     = {}
}


###
# EC2
###
variable "instance_type" {
  description = "The instance type to use for the instance. "
  default     = "t2.micro"
}

variable "instance_extra_tags" {
  description = "A map of tags to assign to the resource."
  default     = {}
}

variable "key_name" {
  description = "Key name of the Key Pair to use for the instance."
  default     = ""
}

//EC2- Network
variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address with an instance in a VPC."
  default     = true
}

//EC2- Storage
variable "enable_vm_disk_delete_on_termination" {
  description = "Whether the volume should be destroyed on instance termination."
  default     = true
}

variable "vm_disk_size" {
  description = "Size of the volume in gibibytes (GiB)."
  default     = 100
}
variable "es_disk_type" {
  description = "Type of volume."
  default     = "gp2"
}
variable "ebs_optimized" {
  description = "If true, the launched EC2 instance will be EBS-optimized."
  default     = false
}