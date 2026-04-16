resource "cloudflare_zero_trust_tunnel_cloudflared_config" "tunnel_config" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.sovereign_tunnel.id

  config = {
    ingress = [          
      {
        hostname = "auth.charif-labs.tech"
        service  = "http://keycloak-server:8080"
      },
      {
        hostname = "mgmt.charif-labs.tech"
        service  = "http://portainer:9000"
      },
      {
        service = "http_status:404"
      }
    ]
  }
}

resource "cloudflare_dns_record" "mgmt_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "mgmt"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.sovereign_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
}