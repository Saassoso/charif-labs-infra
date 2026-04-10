resource "cloudflare_zero_trust_tunnel_cloudflared_config" "tunnel_config" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.sovereign_tunnel.id

  config {
    # Routage Keycloak
    ingress_rule {
      hostname = "auth.charif-labs.tech"
      service  = "http://keycloak-server:8080"
    }

    # Routage Portainer
    ingress_rule {
      hostname = "mgmt.charif-labs.tech"
      service  = "http://portainer:9000"
    }

    ingress_rule {
      service = "http_status:404"
    }
  }
}

resource "cloudflare_record" "mgmt_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "mgmt"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.sovereign_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
}