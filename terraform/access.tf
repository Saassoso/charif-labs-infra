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
      claim_name           = "groups"
      claim_value          = "it-admin"
    }
  }]
}

# --- Application Access (DRY using for_each) ---
locals {
  access_apps = {
    wazuh = {
      name   = "Wazuh Dashboard"
      domain = "wazuh.${var.domain_name}"
    }
    n8n = {
      name   = "n8n Dashboard"
      domain = "n8n.${var.domain_name}"
    }
    grafana = {
      name   = "Grafana Monitoring"
      domain = "grafana.${var.domain_name}"
    }
    portainer = {
      name   = "Portainer Management"
      domain = "mgmt.${var.domain_name}"
    }
  }
}

resource "cloudflare_zero_trust_access_application" "managed_apps" {
  for_each = local.access_apps

  zone_id          = var.cloudflare_zone_id
  name             = each.value.name
  domain           = each.value.domain
  type             = "self_hosted"
  session_duration = "8h"

  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.keycloak_oidc.id]
  auto_redirect_to_identity = true

  policies = [{
    id         = cloudflare_zero_trust_access_policy.admin_only_policy.id
    precedence = 1
  }]
}

# --- Specific Policy for IT Admins  & (Breakglass) ---
resource "cloudflare_zero_trust_access_policy" "keycloak_admin_policy" {
  account_id = var.cloudflare_account_id
  name       = "Keycloak Admin Access (IT Admins & Breakglass)"
  decision   = "allow"

  include = [
    {
      # 1. Allow standard IT Admins via OIDC
      oidc = {
        identity_provider_id = cloudflare_zero_trust_access_identity_provider.keycloak_oidc.id
        claim_name           = "groups"
        claim_value          = "it-admin"
      }
    },
    {
      # 2. Allow the Emergency Breakglass email
      email = { email = var.admin_email }
    }
  ]
}

# --- Keycloak Admin Console (Dedicated Subdomain) ---
resource "cloudflare_zero_trust_access_application" "auth_admin_app" {
  zone_id          = var.cloudflare_zone_id
  name             = "Keycloak Admin Console"
  domain           = "keycloak-admin.${var.domain_name}"
  type             = "self_hosted"
  session_duration = "2h"

  allowed_idps              = [cloudflare_zero_trust_access_identity_provider.keycloak_oidc.id]
  auto_redirect_to_identity = true

  policies = [{
    id         = cloudflare_zero_trust_access_policy.keycloak_admin_policy.id
    precedence = 1
  }]
}

