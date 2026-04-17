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
    claims        = ["openid", "email", "profile", "groups", "ztna_role"]
  }
}

# --- Standalone Reusable Policy (v5 style) ---
resource "cloudflare_zero_trust_access_policy" "admin_only_policy" {
  account_id = var.cloudflare_account_id
  name       = "Allow IT Admins Only"
  decision   = "allow"

  include = [{
    oidc = {
      identity_provider_id = cloudflare_zero_trust_access_identity_provider.keycloak_oidc.id
      claim_name           = "ztna_role"
      claim_value          = "it-admin"
    }
  }]
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

  # v5: policies are attached here, not on the policy resource
  policies = [{
    id         = cloudflare_zero_trust_access_policy.admin_only_policy.id
    precedence = 1
  }]
}

# PORTAINER
resource "cloudflare_zero_trust_access_application" "portainer_app" {
  zone_id                   = var.cloudflare_zone_id
  name                      = "Portainer Management"
  domain                    = "mgmt.charif-labs.tech"
  type                      = "self_hosted"
  session_duration          = "8h"
  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.keycloak_oidc.id]
  auto_redirect_to_identity = true
  
  # v5: policies are attached here, not on the policy resource
  policies = [{
    id         = cloudflare_zero_trust_access_policy.admin_only_policy.id
    precedence = 1
  }]
}

# AUTH Keycloak 
#resource "cloudflare_zero_trust_access_application" "auth_admin_app" {
#  zone_id                   = var.cloudflare_zone_id
# name                      = "Keycloak Admin Console"
# domain                    = "auth.charif-labs.tech/admin/*" # Protège uniquement l'accès admin
# type                      = "self_hosted"
# session_duration          = "8h"
# allowed_idps              = [cloudflare_zero_trust_access_identity_provider.keycloak_oidc.id]
# auto_redirect_to_identity = true
# 
# # v5: policies are attached here, not on the policy resource
# policies = [{
#   id         = cloudflare_zero_trust_access_policy.admin_only_policy.id
#   precedence = 1
# }]
#}