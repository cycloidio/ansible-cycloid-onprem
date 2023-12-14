
resource "random_password" "cy" {
  for_each = toset(["concourse", "postgres", "mysql", "user", "signing", "elasticsearch"])
  length   = 32
  special  = false
  # override_special = "!#$%*-_"
}

output "password" {
  value = {
    for key, value in random_password.cy :
    key => value.result
  }

  sensitive = true
}
