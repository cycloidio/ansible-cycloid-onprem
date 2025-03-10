data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
    ]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
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

resource "aws_iam_role_policy_attachment" "instance-ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.cy_instances.name
}

resource "aws_iam_instance_profile" "cy_instances" {
  name = "profile-cy_instances-${var.project}-${var.env}"
  role = aws_iam_role.cy_instances.name
}

