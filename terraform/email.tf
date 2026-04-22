# 1. Define the Destination Address (Your personal Gmail)
resource "cloudflare_email_routing_address" "gmail_destination" {
  account_id = var.cloudflare_account_id
  email      = "tisamplework@gmail.com"
}

# 2. Create the Catch-All Rule
resource "cloudflare_email_routing_catch_all" "catch_all" {
  zone_id = var.cloudflare_zone_id
  name    = "Catch all rule for charif-labs.tech"
  enabled = true

  matchers = [{
    type = "all"
  }]

  actions = [{
    type  = "forward"
    value = [cloudflare_email_routing_address.gmail_destination.email]
  }]

  # Ensure the destination is created before the rule
  depends_on = [
    cloudflare_email_routing_address.gmail_destination
  ]
}