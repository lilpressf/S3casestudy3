locals {
  portal_fqdn = "${var.portal_subdomain}.${var.hosted_zone_name}"
}

resource "aws_route53_zone" "main" {
  name = var.hosted_zone_name
}

resource "aws_acm_certificate" "portal" {
  domain_name       = local.portal_fqdn
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "portal_cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.portal.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}

resource "aws_acm_certificate_validation" "portal" {
  certificate_arn         = aws_acm_certificate.portal.arn
  validation_record_fqdns = [for record in aws_route53_record.portal_cert_validation : record.fqdn]
}

resource "aws_route53_record" "portal_alb" {
  zone_id = aws_route53_zone.main.zone_id
  name    = local.portal_fqdn
  type    = "A"

  alias {
    name                   = aws_lb.public_alb.dns_name
    zone_id                = aws_lb.public_alb.zone_id
    evaluate_target_health = false
  }

  depends_on = [aws_acm_certificate_validation.portal]
}
