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
       hostname = "keycloak-admin.charif-labs.tech"
       service  = "http://keycloak-server:8080"
      },      
      {
        hostname = "wazuh.charif-labs.tech"
        service  = "https://sovereign-stack-wazuh.dashboard-1:5601"
        origin_request = {
          no_tls_verify = true
        }
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

resource "cloudflare_dns_record" "keycloak_admin_dns" {
  zone_id = var.cloudflare_zone_id
  name    = "keycloak-admin"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.sovereign_tunnel.id}.cfargotunnel.com"
  type    = "CNAME"
  proxied = true
  ttl     = 1
}