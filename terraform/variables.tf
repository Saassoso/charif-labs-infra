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

variable "keycloak_client_id" {
  type        = string
  description = "Client ID pour Cloudflare Access dans Keycloak"
  default     = "cloudflare-access"
}

variable "keycloak_client_secret" {
  type        = string
  description = "Client Secret généré par Keycloak"
  sensitive   = true
}