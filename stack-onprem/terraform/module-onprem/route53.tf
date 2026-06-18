variable "dns_zone" {
  default = "cycloid.io"
}

variable "subdns_zone" {
  default = "onprem"
}

data "aws_route53_zone" "onprem" {
  name = var.dns_zone
}

resource "aws_route53_record" "console" {
  zone_id = data.aws_route53_zone.onprem.zone_id
  name    = "${var.project}-${var.env}-console.${var.subdns_zone}.${data.aws_route53_zone.onprem.name}"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.cy_instances[0].public_ip]
}

resource "aws_route53_record" "ai" {
  zone_id = data.aws_route53_zone.onprem.zone_id
  name    = "${var.project}-${var.env}-ai.${var.subdns_zone}.${data.aws_route53_zone.onprem.name}"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.cy_instances[0].public_ip]
}

resource "aws_route53_record" "mcp" {
  zone_id = data.aws_route53_zone.onprem.zone_id
  name    = "${var.project}-${var.env}-mcp.${var.subdns_zone}.${data.aws_route53_zone.onprem.name}"
  type    = "A"
  ttl     = "300"
  records = [aws_eip.cy_instances[0].public_ip]
}

# resource "aws_route53_record" "api" {
#   zone_id = data.aws_route53_zone.onprem.zone_id
#   name    = "${var.project}-${var.env}-api.${var.subdns_zone}.${data.aws_route53_zone.onprem.name}"
#   type    = "A"
#   ttl     = "300"
#   records = [aws_eip.instance.public_ip]
# }

output "cy_instances_records" {
  value = {
    "console" = aws_route53_record.console.fqdn
    "api"     = "https://${aws_route53_record.console.fqdn}/api"
    "ai"      = aws_route53_record.ai.fqdn
    "mcp"     = aws_route53_record.mcp.fqdn
    # "api"     = aws_route53_record.api.fqdn
  }
}
