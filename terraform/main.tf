# Generate a secure, random 35-byte secret for the Cloudflare Tunnel
resource "random_id" "tunnel_secret" {
  byte_length = 35
}

# Create the Zero-Trust Tunnel
resource "cloudflare_zero_trust_tunnel_cloudflared" "sovereign_tunnel" {
  account_id = var.cloudflare_account_id
  name       = "sovereign-stack-tunnel"
  tunnel_secret   = random_id.tunnel_secret.b64_std
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
resource "cloudflare_dns_record" "tunnel_cnames" {
  for_each = toset(local.services)
  
  zone_id  = var.cloudflare_zone_id
  name     = each.key
  content    = "${cloudflare_zero_trust_tunnel_cloudflared.sovereign_tunnel.id}.cfargotunnel.com"
  type     = "CNAME"
  proxied  = true
  ttl      = 1
}

# microsoft_verification subdomains 
resource "cloudflare_dns_record" "microsoft_verification" {
  zone_id = var.cloudflare_zone_id
  name    = "ms"
  content = "MS=ms76330167"
  type    = "TXT"
  ttl     = 1
}

# google_site_verification domains
resource "cloudflare_dns_record" "google_site_verification" {
  zone_id = var.cloudflare_zone_id
  name    = "@"          
  type    = "TXT"
  content   = "google-site-verification=GBYb7L-TSlLVejW0eKSmT1y7gGIJjM-cvl8TKxx9lIQ"
  ttl     = 3600         
  comment = "Google domain verification — managed by Terraform"
}


# Output the tunnel token (For Docker Compose)
output "cloudflare_zero_trust_tunnel_cloudflared_token" {
  description = "Token to configure cloudflared daemon in Docker"
  # Astuce v5 : On génère le token Base64 manuellement 
  value       = base64encode(jsonencode({
    a = var.cloudflare_account_id
    t = cloudflare_zero_trust_tunnel_cloudflared.sovereign_tunnel.id
    s = random_id.tunnel_secret.b64_std
  }))
  sensitive   = true
}