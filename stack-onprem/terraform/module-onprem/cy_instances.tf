###
# variables
###

variable "cy_instances_disk_size" {
  default = 30
}

variable "cy_instances_disk_type" {
  default = "gp2"
}

variable "cy_instances_disk_device_name" {
  default = "/dev/xvdf"
}

variable "cy_instances_type" {
  default = "t3.small"
}

variable "cy_instances_ebs_optimized" {
  default = false
}

variable "cy_instances_count" {
  default = 1
}

variable "cy_instances_root_disk_size" {
  default = 20
}

variable "cy_instances_root_disk_type" {
  default = "gp2"
}

variable "cy_instances_root_delete_on_termination" {
  default = true
}

variable "cy_instances_cidr_blocks_allow" {
  default = ["0.0.0.0/0"]
}

###
# Iam role profile
###

# Create IAM Role for cy_instances
resource "aws_iam_role" "cy_instances" {
  name               = "cy_instances-${var.project}-${var.env}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  path               = "/${var.project}/"
}

resource "aws_iam_instance_profile" "cy_instances" {
  name = "profile-cy_instances-${var.project}-${var.env}"
  role = aws_iam_role.cy_instances.name
}


###

# cy_instances

###

resource "aws_security_group" "cy_instances" {
  name        = "${var.project}-cy_instances-${var.env}"
  description = "cy_instances ${var.env} for ${var.project}"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    self        = true
    cidr_blocks = var.cy_instances_cidr_blocks_allow
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    self        = true
    cidr_blocks = var.cy_instances_cidr_blocks_allow
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    self        = true
    cidr_blocks = var.cy_instances_cidr_blocks_allow
  }

  ingress {
    from_port   = 8025
    to_port     = 8025
    protocol    = "tcp"
    self        = true
    cidr_blocks = var.cy_instances_cidr_blocks_allow
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.merged_tags, {
    Name = "${var.project}-cy_instances-${var.env}"
    role = "cy_instances"
  })
}

#
# instances
#

resource "random_shuffle" "cy_instances_az" {
  input        = local.aws_availability_zones
  result_count = var.cy_instances_count
}

resource "aws_ebs_volume" "cy_instances" {
  count             = var.cy_instances_count
  availability_zone = element(random_shuffle.cy_instances_az.result, count.index)
  size              = var.cy_instances_disk_size
  type              = var.cy_instances_disk_type

  tags = merge(local.merged_tags, {
    Name = "${var.project}-cy_instances-${count.index}-${var.env}"
    role = "cy_instances"
  })
}

resource "aws_instance" "cy_instances" {
  ami                  = local.image_id
  count                = var.cy_instances_count
  iam_instance_profile = aws_iam_instance_profile.cy_instances.name
  ebs_optimized        = var.cy_instances_ebs_optimized
  instance_type        = var.cy_instances_type
  key_name             = var.keypair_name
  subnet_id            = tolist(var.public_subnets_ids)[count.index % length(var.public_subnets_ids)]
  availability_zone    = aws_ebs_volume.cy_instances[count.index].availability_zone

  vpc_security_group_ids = compact([
    var.bastion_sg_allow,
    aws_security_group.cy_instances.id
  ])

  root_block_device {
    volume_size           = var.cy_instances_root_disk_size
    volume_type           = var.cy_instances_root_disk_type
    delete_on_termination = var.cy_instances_root_delete_on_termination
  }

  tags = merge(local.merged_tags, {
    Name = "${var.project}-cy_instances-${count.index}-${var.env}"
    role = "cy_instances"
  })

  volume_tags = merge(local.merged_tags, {
    Name = "${var.project}-cy_instances-${count.index}-${var.env}"
    role = "cy_instances"
  })
}

resource "aws_volume_attachment" "cy_instances" {
  count       = var.cy_instances
  device_name = var.cy_instances_disk_device_name
  volume_id   = aws_ebs_volume.cy_instances[count.index].id
  instance_id = aws_instance.cy_instances[count.index].id
}

resource "aws_eip" "cy_instances" {
  count    = var.cy_instances_count
  instance = aws_instance.cy_instances[count.index].id
  vpc      = true
}

output "cy_instances_public_dns" {
  description = "List of public DNS addresses assigned to the instances"
  value       = aws_eip.cy_instances.*.public_dns
}

output "cy_instances_public_ip" {
  description = "List of public IP addresses assigned to the instances"
  value       = aws_eip.cy_instances.*.public_ip
}

output "cy_instances_private_ip" {
  description = "List of private IP addresses assigned to the instances"
  value       = aws_eip.cy_instances.*.private_ip
}
