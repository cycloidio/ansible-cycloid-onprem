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

output "es_instance_public_ip" {
  value       = module.es.ip_address
  description = "Elasticsearch instance IP."
}