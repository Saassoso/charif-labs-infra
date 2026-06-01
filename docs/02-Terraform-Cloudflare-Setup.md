# 02 — Terraform Cloudflare Setup

> This phase creates every Cloudflare resource: the Zero Trust Tunnel, DNS records, Email routing, and Access Applications. All changes are tracked in Terraform state.

---

## 2.1 Navigate to the Terraform Directory

```bash
cd terraform/
```

---

## 2.2 Create `terraform.tfvars`

This file contains sensitive values. It is already `.gitignore`-d.

```bash
cat > terraform.tfvars << 'EOF'
cloudflare_account_id = "paste-your-account-id-here"
cloudflare_zone_id    = "paste-your-zone-id-here"
cloudflare_api_token  = "paste-your-api-token-here"
keycloak_client_secret = "placeholder-will-update-later"
forwarding_email       = "your-gmail@gmail.com"
admin_email            = "your-admin-email@gmail.com"
ms_verification_code   = "MS=msxxxxxxx"
google_site_verification_code = "google-site-verification=..."
EOF
```

Replace the placeholders with values gathered in [01 — Prerequisites](01-Prerequisites-and-Architecture.md).

> ⚠️ **Security:** Never commit this file. Verify `.gitignore` contains `*.tfvars`.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/02-tfvars-example.png`
> **Description:** A text editor or terminal showing a completed `terraform.tfvars` with values redacted/blurred.

---

## 2.3 Understand What Will Be Created

Open each file to inspect the resources:

| File | What It Creates |
|------|-----------------|
| `provider.tf` | Cloudflare provider (v5.x) binding |
| `main.tf` | Random tunnel secret, Tunnel resource, DNS CNAMEs, TXT verification records |
| `ingress.tf` | Tunnel ingress rules mapping hostnames → internal Docker services |
| `access.tf` | Keycloak OIDC Identity Provider, Access Policies, Access Applications |
| `email.tf` | Email routing destination + catch-all rule |
| `rules.tf` | HTTP redirect rules (e.g. `iam.` → Keycloak admin console) |
| `tcp.tf` | Extra DNS records for Wazuh agent/auth subdomains |
| `moved.tf` | State migration blocks (v4 → v5 provider upgrade). Leave as-is. |

### DNS Records Created Automatically

| Hostname | Type | Target |
|----------|------|--------|
| `auth.charif-labs.tech` | CNAME | `<tunnel-id>.cfargotunnel.com` |
| `wazuh.charif-labs.tech` | CNAME | `<tunnel-id>.cfargotunnel.com` |
| `mgmt.charif-labs.tech` | CNAME | `<tunnel-id>.cfargotunnel.com` |
| `n8n.charif-labs.tech` | CNAME | `<tunnel-id>.cfargotunnel.com` |
| `grafana.charif-labs.tech` | CNAME | `<tunnel-id>.cfargotunnel.com` |
| `iam.charif-labs.tech` | CNAME | `<tunnel-id>.cfargotunnel.com` |
| `keycloak-admin.charif-labs.tech` | CNAME | `<tunnel-id>.cfargotunnel.com` |
| `wazuh-agent.charif-labs.tech` | CNAME | `<tunnel-id>.cfargotunnel.com` |
| `wazuh-auth.charif-labs.tech` | CNAME | `<tunnel-id>.cfargotunnel.com` |
| `ms.charif-labs.tech` | TXT | Microsoft verification code |
| `@` (apex) | TXT | Google site verification code |

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/02-dns-records-overview.png`
> **Description:** Cloudflare Dashboard → DNS → Records table showing all CNAME and TXT records created.
> **When to capture:** After `terraform apply` succeeds.

---

## 2.4 Initialize Terraform

```bash
terraform init
```

**What this does:**
- Downloads the Cloudflare provider plugin (~> 5.0)
- Creates the local state backend directory `.terraform/`
- Validates provider configuration

Expected output:
```
Initializing the backend...
Initializing provider plugins...
- Finding cloudflare/cloudflare versions matching "~> 5.0"...
```

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/02-terraform-init.png`
> **Description:** Terminal showing successful `terraform init` output.

---

## 2.5 Plan the Changes

```bash
terraform plan
```

**What this does:**
- Reads all `.tf` files in the directory
- Compares desired state with actual Cloudflare resources
- Shows a preview of every create/update/destroy action

Review the plan carefully. You should see:
- `cloudflare_zero_trust_tunnel_cloudflared.sovereign_tunnel` — **create**
- `cloudflare_dns_record.tunnel_cnames["auth"]` — **create**
- `cloudflare_dns_record.tunnel_cnames["wazuh"]` — **create**
- `cloudflare_zero_trust_tunnel_cloudflared_config.tunnel_config` — **create**
- `cloudflare_zero_trust_access_identity_provider.keycloak_oidc` — **create**
- `cloudflare_zero_trust_access_application.*` — **create**
- `cloudflare_email_routing_catch_all.catch_all` — **create**
- `cloudflare_ruleset.realm_redirects` — **create**

> **Note:** `keycloak_client_secret` is currently a placeholder. The Keycloak IdP resource will be created but non-functional until Phase 4.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/02-terraform-plan.png`
> **Description:** Terminal showing the `terraform plan` summary (e.g. "Plan: 15 to add, 0 to change, 0 to destroy").

---

## 2.6 Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted.

### What Happens During Apply

1. **Random secret generation** — `random_id.tunnel_secret` creates a 35-byte secure secret.
2. **Tunnel provisioning** — Cloudflare creates the tunnel and returns a unique ID.
3. **DNS records** — CNAMEs and TXT records are created in your zone.
4. **Tunnel config** — Ingress rules mapping hostnames to internal Docker services are uploaded.
5. **Email routing** — Destination address is verified and catch-all rule is enabled.
6. **Zero Trust Access** — Identity provider, policies, and applications are created.
7. **Redirect rules** — `iam.` and `keycloak-admin.` naked-domain redirects are configured.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/02-terraform-apply-success.png`
> **Description:** Terminal showing "Apply complete! Resources: 15 added, 0 changed, 0 destroyed."

---

## 2.7 Extract the Tunnel Token

After apply completes, retrieve the tunnel token:

```bash
terraform output -raw cloudflare_zero_trust_tunnel_cloudflared_token
```

**What this outputs:**
A base64-encoded JSON object containing:
- `a` — your Cloudflare Account ID
- `t` — the Tunnel ID
- `s` — the 35-byte tunnel secret

Copy this long base64 string. You will paste it into Docker in Phase 3 as `TUNNEL_TOKEN`.

> 🔐 This token is **sensitive**. Treat it like a password. Anyone with it can hijack your tunnel.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/02-tunnel-token-output.png`
> **Description:** Terminal showing the `terraform output -raw` command with the token value redacted.

---

## 2.8 Verify Resources in Cloudflare Dashboard

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) → select your zone.
2. **DNS → Records** — confirm CNAMEs exist and are **Proxied** (orange cloud).
3. **Zero Trust → Networks → Tunnels** — confirm `sovereign-stack-tunnel` is listed.
4. **Zero Trust → Access → Applications** — confirm Wazuh, Portainer, n8n, Grafana, and Keycloak Admin apps exist.
5. **Email → Email Routing** — confirm catch-all rule is enabled.
6. **Rules → Page Rules / Redirect Rules** — confirm redirect rules exist.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/02-cloudflare-tunnel-listed.png`
> **Description:** Cloudflare Dashboard → Zero Trust → Networks → Tunnels showing `sovereign-stack-tunnel` as healthy.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/02-cloudflare-access-apps.png`
> **Description:** Cloudflare Dashboard → Zero Trust → Access → Applications list showing all self-hosted apps.

---

## 2.9 Troubleshooting

### Error: "Invalid API token"
```
Error: Authentication error (10000)
```
**Fix:** Regenerate the token with `Zone:Read`, `DNS:Edit`, `Account:Read`, `Access:Edit`, and `Email Routing:Edit` permissions.

### Error: "Record already exists"
```
Error: failed to create DNS record: already exists.
```
**Fix:** Import the existing record into Terraform state:
```bash
terraform import cloudflare_dns_record.tunnel_cnames[\"auth\"] <zone_id>/<record_id>
```
Or delete the manual record first.

### Tunnel Token Output is Empty
```bash
terraform output cloudflare_zero_trust_tunnel_cloudflared_token
```
Returns nothing? Ensure `sensitive = true` is not hiding it. Use:
```bash
terraform output -raw cloudflare_zero_trust_tunnel_cloudflared_token
```

---

## 2.10 State & Backup

Terraform stores state in `terraform.tfstate`. This file contains sensitive data and is `.gitignore`-d. Back it up securely:

```bash
cp terraform.tfstate terraform.tfstate.backup.$(date +%s)
```

For team environments, migrate to a remote backend (S3, Terraform Cloud, etc.):
```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "charif-labs-infra/terraform.tfstate"
    region = "us-east-1"
  }
}
```

---

**Next Step:** [03 — Docker Sovereign Stack](03-Docker-Sovereign-Stack.md)
