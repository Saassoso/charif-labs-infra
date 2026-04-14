# --- Fournisseur d'Identité Keycloak ---
resource "cloudflare_zero_trust_access_identity_provider" "keycloak_oidc" {
  account_id = var.cloudflare_account_id
  name       = "Keycloak"
  type       = "oidc"

config = {
    client_id     = var.keycloak_client_id
    client_secret = var.keycloak_client_secret
    auth_url      = "https://auth.charif-labs.tech/realms/charif-labs/protocol/openid-connect/auth"
    token_url     = "https://auth.charif-labs.tech/realms/charif-labs/protocol/openid-connect/token"
    certs_url     = "https://auth.charif-labs.tech/realms/charif-labs/protocol/openid-connect/certs"
    claims        = ["openid", "email", "profile", "groups"]
  }
}

# --- Application Access ---
resource "cloudflare_zero_trust_access_application" "wazuh_app" {
  zone_id                   = var.cloudflare_zone_id
  name                      = "Wazuh Dashboard"
  domain                    = "wazuh.charif-labs.tech"
  type                      = "self_hosted"
  session_duration          = "8h"
  
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.keycloak_oidc.id]  
  auto_redirect_to_identity = true
}

# Access Policy 
resource "cloudflare_zero_trust_access_policy" "wazuh_policy" {
  account_id     = var.cloudflare_account_id
  
  application_id = cloudflare_zero_trust_access_application.wazuh_app.id 
  
  name           = "Allow IT Admins Only"
  decision       = "allow"

  include = [{
    email_domain = { domain = "charif-labs.tech" }
  }]

  require = [{
    oidc = {
      identity_provider_id = cloudflare_zero_trust_access_identity_provider.keycloak_oidc.id
      claim_name           = "groups"
      claim_value          = "it-admin"
    }
  }]
}