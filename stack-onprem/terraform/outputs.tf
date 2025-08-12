output "cy_instances_public_dns" {
  value       = module.onprem.cy_instances_public_dns
  description = "Cycloid instances ips."
}

output "cy_instances_public_ip" {
  value       = module.onprem.cy_instances_public_ip
  description = "Cycloid instances ips."
}

output "cy_instances_private_ip" {
  value       = module.onprem.cy_instances_private_ip
  description = "Cycloid instances ips."
}

output "cy_instances_id" {
  value = module.onprem.cy_instances_id
}

output "cy_instances_records" {
  value       = module.onprem.cy_instances_records
  description = "Route53 records."
}

output "password" {
  value     = module.onprem.password
  sensitive = true
}

output "iam_ses_smtp_user_key" {
  value     = module.onprem.iam_ses_smtp_user_key
  sensitive = true
}

output "iam_ses_smtp_user_secret" {
  value     = module.onprem.iam_ses_smtp_user_secret
  sensitive = true
}

output "enable_monitoring" {
  value = module.onprem.enable_monitoring
}
