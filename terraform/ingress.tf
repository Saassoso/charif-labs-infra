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
        # UPDATED
        hostname = "grafana.${var.domain_name}"
        service  = "http://app-observability-grafana-1:3000"
      },
      {
        # UPDATED
        hostname = "wazuh.${var.domain_name}"
        service  = "https://app-security-wazuh.dashboard-1:5601"
        origin_request = {
          no_tls_verify = true
        }
      },
      {
        # UPDATED
        hostname = "n8n.${var.domain_name}"
        service  = "http://app-automation-n8n-1:5678"
      },
      # --- ADDED WAZUH TCP ROUTES HERE ---
      {
        hostname = "wazuh-agent.${var.domain_name}"
        service  = "tcp://10.0.30.2:1514"
      },
      {
        hostname = "wazuh-auth.${var.domain_name}"
        service  = "tcp://10.0.30.2:1515"
      },
      {
        service = "http_status:404"
      }
    ]
  }
}