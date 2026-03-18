# Fetch the existing Cloudflare Zone based on your domain variable
data "cloudflare_zone" "main" {
  name = var.domain_name
}

# Generate a secure, random 35-byte secret for the Cloudflare Tunnel
resource "random_id" "tunnel_secret" {
  byte_length = 35
}

# Create the Zero-Trust Tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "sovereign_tunnel" {
  account_id = data.cloudflare_zone.main.account_id
  name       = "sovereign-stack-tunnel"
  secret     = random_id.tunnel_secret.b64_std
}

# Define the subdomains exactly as required by the Sovereign Security Stack v2.0
locals {
  services = [
    "auth",  # Authentik SSO 
    "trmm",  # Tactical RMM 
    "n8n",   # SOAR Automation 
    "wazuh"  # XDR Dashboard 
  ]
}

# Iterate through the subdomains and create proxied CNAME records pointing to the tunnel
resource "cloudflare_record" "tunnel_cnames" {
  for_each = toset(local.services)
  
  zone_id  = data.cloudflare_zone.main.id
  name     = each.key
  content    = "${cloudflare_zero_trust_tunnel_cloudflared.sovereign_tunnel.id}.cfargotunnel.com"
  type     = "CNAME"
  proxied  = true
}

resource "cloudflare_record" "google_placeholder" {
  zone_id = data.cloudflare_zone.main.id
  name    = "id"
  content = "192.0.2.1" 
  type    = "A"
  proxied = false
}

resource "cloudflare_record" "microsoft_verification" {
  zone_id = data.cloudflare_zone.main.id
  name    = "ms"
  content = "MS=ms76330167"
  type    = "TXT"
  ttl     = 1
}

# Output the tunnel token (For Docker Compose)
output "cloudflare_zero_trust_tunnel_cloudflared_token" {
  description = "Token to configure cloudflared daemon in Docker"
  value     = cloudflare_zero_trust_tunnel_cloudflared.sovereign_tunnel.tunnel_token
  sensitive   = true
}