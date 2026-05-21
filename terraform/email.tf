# ============================================================================
# CLOUDFLARE EMAIL ROUTING (CLEAN CATCH-ALL)
# ============================================================================

# Define the verified destination Gmail address
resource "cloudflare_email_routing_address" "gmail_destination" {
  account_id = var.cloudflare_account_id
  email      = var.forwarding_email
}

# Catch-All Routing Logic
resource "cloudflare_email_routing_catch_all" "catch_all" {
  zone_id = var.cloudflare_zone_id
  name    = "Catch all rule for ${var.domain_name}"
  enabled = true

  matchers = [{
    type = "all"
  }]

  actions = [{
    type  = "forward"
    value = [cloudflare_email_routing_address.gmail_destination.email]
  }]
}