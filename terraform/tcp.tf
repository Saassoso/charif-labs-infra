resource "cloudflare_dns_record" "wazuh_agent_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "wazuh-agent"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.sovereign_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl = 1
}

resource "cloudflare_dns_record" "wazuh_auth_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "wazuh-auth"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.sovereign_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl = 1
}