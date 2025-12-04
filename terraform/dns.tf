variable "alb_dns_name" {
  type    = string
  default = ""
}

resource "aws_route53_record" "portal" {
  count   = var.alb_dns_name == "" ? 0 : 1

  zone_id = data.aws_route53_zone.main.zone_id
  name    = "portal.daanwelten.nl"
  type    = "CNAME"
  ttl     = 60
  records = [var.alb_dns_name]
}
