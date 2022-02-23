###
# variables
###

variable "es_instance_disk_size" {
  default = 100
}

variable "es_instance_disk_type" {
  default = "gp2"
}

variable "es_instance_type" {
  default = "t2.large"
}

variable "es_instance_ebs_optimized" {
  default = false
}

variable "es_instance_root_delete_on_termination" {
  default = true
}

###
# Iam role profile
###

# Create IAM Role for es_instance
resource "aws_iam_role" "es_instance" {
  name               = "es_instances-${var.project}-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  path               = "/${var.project}/"
}

resource "aws_iam_instance_profile" "es_instance" {
  name = "profile-es_instance-${var.project}-${var.env}"
  role = aws_iam_role.es_instance.name
}

###
# Security Group
###

resource "aws_security_group" "ec2" {
  name        = local.security_group_name
  description = "es_instance ${var.env} for ${var.project}"
  vpc_id      = var.vpc_id

  ingress = var.sg_ingress_rules
  egress  = var.sg_egress_rules

  tags = local.sg_tags
}

###
# EC2
###

resource "aws_instance" "es_instance" {
  ami           = data.aws_ami.es.id
  instance_type = var.es_instance_type
    iam_instance_profile = aws_iam_instance_profile.es_instance.name

  // keypair name - if enabled
  key_name = var.key_name

  //network
  vpc_security_group_ids      = module.onprem.cy_instances.vpc_security_group_ids
  subnet_id                   = module.onprem.cy_instances.subnet_id
  associate_public_ip_address = var.associate_public_ip_address

  //storage
  root_block_device {
    delete_on_termination = var.es_instance_root_delete_on_termination
    volume_size           = var.es_instance_disk_size
    volume_type           = var.es_instance_disk_type
  }
  ebs_optimized = var.es_instance_ebs_optimized
  volume_tags   = local.es_volume_tags

  //tags
  tags = module.onprem.cy_instances.tags
}