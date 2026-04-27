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
EOF
```

Replace the placeholders with values gathered in [01 — Prerequisites](01-Prerequisites-and-Architecture.md).

> ⚠️ **Security:** Never commit this file. Verify `.gitignore` contains `*.tfvars`.

---

## 2.3 Understand What Will Be Created

Open each file to inspect the resources:

| File | What It Creates |
|------|-----------------|
| `provider.tf` | Cloudflare provider (v5.x) binding |
| `main.tf` | Random tunnel secret, Tunnel resource, DNS CNAMEs (`auth`, `wazuh`, `trmm`, `n8n`), TXT verification records |
| `ingress.tf` | Tunnel ingress rules mapping hostnames → internal Docker services |
| `access.tf` | Keycloak OIDC Identity Provider, Access Policies, Access Applications (Wazuh, Portainer, Keycloak Admin) |
| `email.tf` | Email routing destination + catch-all rule |
| `moved.tf` | State migration blocks (v4 → v5 provider upgrade). Leave as-is. |

### DNS Records Created Automatically

| Hostname | Type | Target |
|----------|------|--------|
| `auth.charif-labs.tech` | CNAME | `<tunnel-id>.cfargotunnel.com` |
| `wazuh.charif-labs.tech` | CNAME | `<tunnel-id>.cfargotunnel.com` |
| `mgmt.charif-labs.tech` | CNAME | `<tunnel-id>.cfargotunnel.com` |
| `keycloak-admin.charif-labs.tech` | CNAME | `<tunnel-id>.cfargotunnel.com` |
| `ms.charif-labs.tech` | TXT | `MS=ms76330167` (Microsoft verification) |
| `@` (apex) | TXT | `google-site-verification=...` |

---

## 2.4 Initialize Terraform

```bash
terraform init
```

Expected output:
```
Initializing the backend...
Initializing provider plugins...
- Finding cloudflare/cloudflare versions matching "~> 5.0"...
```

---

## 2.5 Plan the Changes

```bash
terraform plan
```

Review the plan carefully. You should see:
- `cloudflare_zero_trust_tunnel_cloudflared.sovereign_tunnel` — **create**
- `cloudflare_dns_record.tunnel_cnames["auth"]` — **create**
- `cloudflare_dns_record.tunnel_cnames["wazuh"]` — **create**
- `cloudflare_zero_trust_tunnel_cloudflared_config.tunnel_config` — **create**
- `cloudflare_zero_trust_access_identity_provider.keycloak_oidc` — **create**
- `cloudflare_zero_trust_access_application.*` — **create**
- `cloudflare_email_routing_catch_all.catch_all` — **create**

> **Note:** `keycloak_client_secret` is currently a placeholder. The Keycloak IdP resource will be created but non-functional until Phase 4.

---

## 2.6 Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted.

### What Happens During Apply

1. Terraform generates a **35-byte random secret** for the tunnel.
2. Cloudflare provisions the **tunnel** and returns an ID.
3. Terraform creates **DNS records** pointing subdomains to the tunnel.
4. Terraform uploads the **tunnel ingress configuration** (maps hostnames → internal services).
5. Terraform creates **Email routing** destination and catch-all rule.
6. Terraform creates **Zero Trust Access Applications** with placeholder IdP config.

---

## 2.7 Extract the Tunnel Token

After apply completes, retrieve the tunnel token:

```bash
terraform output -raw cloudflare_zero_trust_tunnel_cloudflared_token
```

Copy this long base64 string. You will paste it into Docker in Phase 3 as `TUNNEL_TOKEN`.

> 🔐 This token is **sensitive**. Treat it like a password. Anyone with it can hijack your tunnel.

---

## 2.8 Verify Resources in Cloudflare Dashboard

1. Go to [dash.cloudflare.com](https://dash.cloudflare.com) → select your zone.
2. **DNS → Records** — confirm CNAMEs exist and are **Proxied** (orange cloud).
3. **Zero Trust → Networks → Tunnels** — confirm `sovereign-stack-tunnel` is listed.
4. **Zero Trust → Access → Applications** — confirm Wazuh, Portainer, and Keycloak Admin apps exist.
5. **Email → Email Routing** — confirm catch-all rule is enabled.

---

## 2.9 Troubleshooting

### Error: "Invalid API token"
```
Error: Authentication error (10000)
```
**Fix:** Regenerate the token with `Zone:Read`, `DNS:Edit`, `Account:Read`, and `Access:Edit` permissions.

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
