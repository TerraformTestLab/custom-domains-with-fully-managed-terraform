data "aws_route53_zone" "this" {
  name         = var.route53_hosted_zone_name
  private_zone = false
}

resource "aws_route53_record" "vault_cname" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = format("%s.%s", var.vault_record_name, trimsuffix(var.route53_hosted_zone_name, "."))
  type    = "CNAME"
  ttl     = 300
  records = [var.vault_target_hostname]
}

resource "aws_route53_record" "vault_challenge_cname" {
  zone_id = data.aws_route53_zone.this.zone_id
  name    = format("%s.%s.%s", "_acme-challenge", var.vault_record_name, trimsuffix(var.route53_hosted_zone_name, "."))
  type    = "CNAME"
  ttl     = 300
  records = [format("%s.%s", "_acme-challenge", var.vault_target_hostname)]
}
