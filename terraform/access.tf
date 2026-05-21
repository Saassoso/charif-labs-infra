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

# --- LINK 1: The Charif Labs IAM Dashboard Portal ---
resource "cloudflare_zero_trust_access_application" "iam_portal" {
  zone_id               = var.cloudflare_zone_id
  name                  = "Charif Labs Admin Portal"
  domain                = "iam.${var.domain_name}"
  type                  = "self_hosted"
  app_launcher_visible  = true # Makes this your visual home dashboard
  
  allowed_idps          = [cloudflare_zero_trust_access_identity_provider.keycloak_oidc.id]
  
  policies = [{
    id         = cloudflare_zero_trust_access_policy.admin_only_policy.id
    precedence = 1
  }]
}

# --- LINK 2: The Keycloak Master Admin Console ---
resource "cloudflare_zero_trust_access_policy" "keycloak_admin_perimeter" {
  account_id = var.cloudflare_account_id
  name       = "Keycloak Master Admin Perimeter Guard"
  decision   = "allow"

  include = [{
    # Completely isolates this link to your explicit email PIN
    email = { email = var.admin_email }
  }]
}

resource "cloudflare_zero_trust_access_application" "auth_admin_app" {
  zone_id          = var.cloudflare_zone_id
  name             = "Keycloak Master Console"
  domain           = "keycloak-admin.${var.domain_name}"
  type             = "self_hosted"
  session_duration = "2h"

  policies = [{
    id         = cloudflare_zero_trust_access_policy.keycloak_admin_perimeter.id
    precedence = 1
  }]
}

# --- LINK 3: The Public Auth Engine (No More Loops!) ---
resource "cloudflare_zero_trust_access_policy" "public_auth_bypass" {
  account_id = var.cloudflare_account_id
  name       = "Allow Public Auth Traffic"
  decision   = "bypass"

  include = [{ everyone = {} }]
}

resource "cloudflare_zero_trust_access_application" "public_auth_engine" {
  zone_id = var.cloudflare_zone_id
  name    = "Keycloak Public Login Engine"
  domain  = "auth.${var.domain_name}"
  type    = "self_hosted"

  policies = [{
    id         = cloudflare_zero_trust_access_policy.public_auth_bypass.id
    precedence = 1
  }]
}

resource "cloudflare_zero_trust_access_policy" "webhook_bypass_policy" {
  account_id = var.cloudflare_account_id
  name       = "Allow GitHub Webhooks Bypass"
  decision   = "bypass"

  include = [{
    everyone = {}
  }]
}

resource "cloudflare_zero_trust_access_application" "portainer_webhooks" {
  zone_id = var.cloudflare_zone_id
  name    = "Portainer Webhooks Bypass"
  domain  = "mgmt.${var.domain_name}/api/stacks/webhooks"
  type    = "self_hosted"

  policies = [{
    id         = cloudflare_zero_trust_access_policy.webhook_bypass_policy.id
    precedence = 1
  }]
}