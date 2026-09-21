# Looking the zone up doubles as the existence check: the plan fails with a
# "no matching Route53Zone found" error when the zone is missing.
data "aws_route53_zone" "this" {
  name         = var.hosted_zone_name
  private_zone = false
}

# allow_overwrite adopts a record that already exists instead of failing on a
# duplicate.
resource "aws_route53_record" "vault" {
  zone_id         = data.aws_route53_zone.this.zone_id
  name            = "vault.${var.hosted_zone_name}"
  type            = "CNAME"
  ttl             = 300
  records         = [var.vault_target_hostname]
  allow_overwrite = true
}

resource "aws_route53_record" "challenge" {
  zone_id         = data.aws_route53_zone.this.zone_id
  name            = "_acme-challenge.vault.${var.hosted_zone_name}"
  type            = "CNAME"
  ttl             = 300
  records         = ["_acme-challenge.${var.vault_target_hostname}"]
  allow_overwrite = true
}
