#
# Policies
#

# Create IAM users
resource "aws_iam_user" "ses_smtp_user" {
  name = "${var.project}-${var.env}-ses_smtp_user"
  path = "/${var.project}/"
}


# access key toogle creation
resource "time_rotating" "toggle_interval" {
  rotation_days = 90
}

resource "toggles_leapfrog" "toggle" {
  trigger = time_rotating.toggle_interval.rotation_rfc3339
}

resource "aws_iam_access_key" "ses_smtp_user" {
  user = aws_iam_user.ses_smtp_user.name
}

resource "aws_iam_access_key" "ses_smtp_user-beta" {
  user = aws_iam_user.ses_smtp_user.name
}

# SES Full Access
resource "aws_iam_user_policy_attachment" "email_ses" {
  user       = aws_iam_user.ses_smtp_user.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSESFullAccess"
}




# SES iam

output "iam_ses_key" {
  value = toggles_leapfrog.toggle.alpha ? aws_iam_access_key.ses_smtp_user.id : aws_iam_access_key.ses_smtp_user-beta.id
}

output "iam_ses_secret" {
  sensitive = true
  value     = toggles_leapfrog.toggle.alpha ? aws_iam_access_key.ses_smtp_user.secret : aws_iam_access_key.ses_smtp_user-beta.secret
}

output "iam_ses_smtp_user_key" {
  value = toggles_leapfrog.toggle.alpha ? aws_iam_access_key.ses_smtp_user.id : aws_iam_access_key.ses_smtp_user-beta.id
}

output "iam_ses_smtp_user_secret" {
  sensitive = true
  value     = toggles_leapfrog.toggle.alpha ? aws_iam_access_key.ses_smtp_user.ses_smtp_password_v4 : aws_iam_access_key.ses_smtp_user-beta.ses_smtp_password_v4
}
