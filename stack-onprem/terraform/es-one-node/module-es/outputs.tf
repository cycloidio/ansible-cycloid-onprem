output "ip_address" {
  value = aws_instance.es.public_ip
}

output "instance_id" {
  value = aws_instance.es.id
}