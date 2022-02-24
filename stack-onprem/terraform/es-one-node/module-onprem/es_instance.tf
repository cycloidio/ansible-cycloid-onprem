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

variable "es_instance_cidr_blocks_allow" {
  default = ["0.0.0.0/0"]
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

# es_instance

###

resource "aws_security_group" "es_instance" {
  name        = "${var.project}-es_instance-${var.env}"
  description = "es_instance ${var.env} for ${var.project}"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    self        = true
    cidr_blocks = var.cy_instances_cidr_blocks_allow
  }

  ingress {
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    self        = true
    cidr_blocks = var.cy_instances_cidr_blocks_allow
  }

  # Allow all port internaly (example for: is db splitted ...)
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.merged_tags, {
    Name = "${var.project}-es_instance-${var.env}"
    role = "es_instances"
  })
}

###
# EC2
###

resource "aws_instance" "es_instance" {
  ami           = local.image_id
  instance_type = var.es_instance_type
  iam_instance_profile = aws_iam_instance_profile.es_instance.name
  key_name = aws_instance.cy_instances[0].key_name

  //network
  vpc_security_group_ids = compact([
    var.bastion_sg_allow,
    aws_security_group.es_instance.id
  ])
  subnet_id                   = aws_instance.cy_instances[0].subnet_id
  associate_public_ip_address = var.associate_public_ip_address

  //storage
  root_block_device {
    delete_on_termination = var.es_instance_root_delete_on_termination
    volume_size           = var.es_instance_disk_size
    volume_type           = var.es_instance_disk_type
  }
  ebs_optimized = var.es_instance_ebs_optimized
  volume_tags   = aws_instance.cy_instances[0].volume_tags

  //tags
  tags = merge(local.merged_tags, {
    Name = "${var.project}-es_instance-${var.env}"
    role = "es_instance"
  })
}

resource "aws_eip" "es_instance" {
  instance = aws_instance.es_instance.id
  vpc      = true
}

output "es_instance_public_ip" {
  description = "List of public IP addresse assigned to the instance"
  value       = aws_eip.es_instance.public_ip
}

output "es_instance_private_ip" {
  description = "List of private IP addresses assigned to the instance"
  value       = aws_eip.es_instance.private_ip
}
