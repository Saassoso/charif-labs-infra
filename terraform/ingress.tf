resource "cloudflare_zero_trust_tunnel_cloudflared_config" "tunnel_config" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.sovereign_tunnel.id

  config = {
    ingress = [
      {
        hostname = "auth.${var.domain_name}"
        service  = "http://keycloak-server:8080"
      },
      {
        hostname = "mgmt.${var.domain_name}"
        service  = "http://portainer:9000"
      },
      {
        hostname = "keycloak-admin.${var.domain_name}"
        service  = "http://keycloak-server:8080"
      },
      {
        hostname = "grafana.${var.domain_name}"
        service  = "http://sovereign-stack-grafana-1:3000"
      },
      {
        hostname = "wazuh.${var.domain_name}"
        service  = "https://sovereign-stack-wazuh.dashboard-1:5601"
        origin_request = {
          no_tls_verify = true
        }
      },
      {
        hostname = "n8n.${var.domain_name}"
        service  = "http://n8n:5678"
      },
      {
        service = "http_status:404"
      }
    ]
  }
}