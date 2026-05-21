# ============================================================================
# CLOUDFLARE REDIRECT RULES (FIX NAKED SUBDOMAINS - V5 SPEC)
# ============================================================================

resource "cloudflare_ruleset" "realm_redirects" {
  zone_id     = var.cloudflare_zone_id
  name        = "Keycloak Realm Subdomain Redirects"
  description = "Redirect naked subdomains to their exact Keycloak realm paths"
  kind        = "zone"
  phase       = "http_request_dynamic_redirect"

  rules = [
    # --- RULE 1: IAM to charif-labs Realm ---
    {
      action      = "redirect"
      description = "IAM to Charif-Labs Realm"
      expression  = "(http.host eq \"iam.${var.domain_name}\" and http.request.uri.path eq \"/\")"
      enabled     = true

      action_parameters = {
        from_value = {
          status_code = 301
          target_url = {
            value = "https://iam.${var.domain_name}/realms/charif-labs/account/"
          }
        }
      }
    },

    # --- RULE 2: Keycloak Admin to Master Realm ---
    {
      action      = "redirect"
      description = "Keycloak Admin to Master Realm Console"
      expression  = "(http.host eq \"keycloak-admin.${var.domain_name}\" and http.request.uri.path eq \"/\")"
      enabled     = true

      action_parameters = {
        from_value = {
          status_code = 301
          target_url = {
            value = "https://keycloak-admin.${var.domain_name}/admin/"
          }
        }
      }
    }
  ]
}