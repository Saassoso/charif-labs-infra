variable "cloudflare_api_token" {
  description = "Cloudflare API Token (Requires 'Edit DNS' permissions)"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "The primary domain name for the Sovereign Security Stack"
  type        = string
  default     = "charif-labs.tech"
}

variable "cloudflare_account_id" {
  type = string
}

variable "cloudflare_zone_id" {
  type = string
}