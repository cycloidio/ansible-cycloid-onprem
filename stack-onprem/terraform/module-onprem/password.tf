
resource "random_password" "cy" {
  for_each = toset(["concourse", "postgres", "mysql", "user", "signing", "elasticsearch"])
  length   = 32
  special  = false
  # override_special = "!#$%*-_"
}

resource "random_password" "jwt" {
  length  = 64
  special = false
}

resource "random_uuid" "jwt" {}

output "password" {
  value = merge({
    for key, value in random_password.cy :
    key => value.result
    },
  { "jwt_key" : "${random_uuid.jwt.result}:${random_password.jwt.result}" })

  sensitive = true
}
