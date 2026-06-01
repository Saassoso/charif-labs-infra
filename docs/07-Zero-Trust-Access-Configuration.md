# 07 — Zero Trust Access Configuration

> This phase explains how Cloudflare Zero Trust Access policies work with Keycloak to secure your applications. It covers the logic behind access rules and how to troubleshoot common issues.

---

## 7.1 How Cloudflare Zero Trust Access Works

Cloudflare Zero Trust Access protects your self-hosted applications by enforcing authentication and authorization at the edge of Cloudflare's network. This means:

1.  **No Direct Exposure**: Your services are not directly exposed to the internet. All traffic flows through the Cloudflare Tunnel.
2.  **Identity-Aware Proxy**: Cloudflare acts as an identity-aware proxy. When a user tries to access a protected application (e.g., `wazuh.charif-labs.tech`):
    a.  Cloudflare intercepts the request.
    b.  It redirects the user to your configured Identity Provider (Keycloak in our case) for authentication.
    c.  After successful authentication with Keycloak, Cloudflare evaluates Access Policies.
    d.  If policies allow, Cloudflare issues a signed token to the user's browser, granting access to the application via the tunnel.

### Key Components:

-   **Identity Provider (IdP)**: Keycloak, configured in `terraform/access.tf`.
-   **Access Applications**: Each application (Wazuh, Portainer, n8n, Grafana, Keycloak Admin) has an associated Access Application in Cloudflare, also defined in `terraform/access.tf`.
-   **Access Policies**: Rules defined in `terraform/access.tf` that specify *who* can access *which* application, based on identity (email, group, role) and other criteria.

---

## 7.2 Understanding Access Policies

Access policies determine who can reach your applications. They are applied in precedence order (lower number = higher precedence).

### General Admin Policy (`admin_only_policy`)

This policy, defined in `terraform/access.tf`, allows access only to users who belong to the `it-admin` group in Keycloak.

```terraform
resource "cloudflare_zero_trust_access_policy" "admin_only_policy" {
  account_id = var.cloudflare_account_id
  name       = "Allow IT Admins Only"
  decision   = "allow"

  include = [{
    oidc = {
      identity_provider_id = cloudflare_zero_trust_access_identity_provider.keycloak_oidc.id
      claim_name           = "groups" # Keycloak claim for user groups
      claim_value          = "it-admin"
    }
  }]
}

# This policy is then attached to: Wazuh, n8n, Grafana, Portainer
```

This policy is then linked to most of your self-hosted applications (Wazuh, Portainer, n8n, Grafana) via a `for_each` loop in `terraform/access.tf`.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/07-cloudflare-admin-policy.png`
> **Description:** Cloudflare Zero Trust Dashboard → Access → Policies, showing the "Allow IT Admins Only" policy with its OIDC rule.

### Keycloak Admin Console Policy (`keycloak_admin_perimeter`)

This policy provides stricter access to the Keycloak Master Admin Console. It allows users who are either in the `it-admin` group OR match a specific `admin_email` (defined in `terraform.tfvars`). This acts as a break-glass mechanism.

```terraform
resource "cloudflare_zero_trust_access_policy" "keycloak_admin_perimeter" {
  account_id = var.cloudflare_account_id
  name       = "Keycloak Master Admin Perimeter Guard"
  decision   = "allow"

  include = [
    {
      oidc = {
        identity_provider_id = cloudflare_zero_trust_access_identity_provider.keycloak_oidc.id
        claim_name           = "groups"
        claim_value          = "it-admin"
      }
    },
    {
      email = {
        email = var.admin_email
      }
    }
  ]
}
```

This policy is applied to `keycloak-admin.charif-labs.tech`.

### Public Auth Bypass (`public_auth_bypass`)

This policy is crucial to prevent authentication loops. The Keycloak public login endpoint (`auth.charif-labs.tech`) **must not** be protected by Cloudflare Access, as it is the entry point for authentication.

```terraform
resource "cloudflare_zero_trust_access_policy" "public_auth_bypass" {
  account_id = var.cloudflare_account_id
  name       = "Allow Public Auth Traffic"
  decision   = "bypass"

  include = [{ everyone = {} }]
}
```

This policy is applied to `auth.charif-labs.tech`.

### Portainer Webhooks Bypass (`webhook_bypass_policy`)

This policy allows GitHub Actions (or other CI/CD systems) to trigger Portainer stack updates without OIDC authentication. This specific endpoint (`mgmt.charif-labs.tech/api/stacks/webhooks`) is bypassed for programmatic access.

```terraform
resource "cloudflare_zero_trust_access_policy" "webhook_bypass_policy" {
  account_id = var.cloudflare_account_id
  name       = "Allow GitHub Webhooks Bypass"
  decision   = "bypass"

  include = [{
    everyone = {}
  }]
}
```

This policy is applied to `mgmt.charif-labs.tech/api/stacks/webhooks`.

---

## 7.3 Verifying Access

After setting up Keycloak and applying Terraform, test access to your applications:

1.  **Keycloak Public Login**: Open `https://auth.charif-labs.tech`. You should directly see the Keycloak login page without any Cloudflare Access prompt.
2.  **Keycloak Admin Console**: Open `https://keycloak-admin.charif-labs.tech`. You should be redirected to Keycloak for login. After logging in with an `it-admin` user (or `admin_email`), you should gain access.
3.  **Protected Applications**: Open `https://wazuh.charif-labs.tech`, `https://mgmt.charif-labs.tech`, `https://n8n.charif-labs.tech`, `https://grafana.charif-labs.tech`. For each, you should be redirected to Keycloak for login. After authenticating with a user assigned the `it-admin` role, you should be able to access the application.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/07-wazuh-access-success.png`
> **Description:** Successful access to the Wazuh Dashboard after authenticating through Keycloak and Cloudflare Access.

---

## 7.4 Troubleshooting Access Issues

### 403 Forbidden / Access Denied

-   **Check Keycloak Groups/Roles**: Ensure the user you are logging in with has the `it-admin` group and `ztna_role` attribute set in Keycloak (refer to [Phase 4](04-Keycloak-Identity-Provider.md)).
-   **Cloudflare Audit Logs**: In the Cloudflare Dashboard, go to `Zero Trust` → `Access` → `Audit Logs`. This shows detailed information about why an access request was denied (e.g., policy mismatch, IdP error).

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/07-cloudflare-audit-logs.png`
> **Description:** Cloudflare Zero Trust Dashboard, "Audit Logs" section, showing an example of an access denied entry.

### Authentication Loop

If you get stuck in a redirect loop between Cloudflare and Keycloak:

-   **Verify `public_auth_bypass` Policy**: Ensure the `auth.charif-labs.tech` domain has the `public_auth_bypass` policy applied with a `decision = "bypass"` and `include = [{ everyone = {} }]`.
-   **Keycloak Client Configuration**: Double-check the `Valid Redirect URIs` and `Web Origins` for the `cloudflare-access` client in Keycloak (refer to [Phase 4](04-Keycloak-Identity-Provider.md)). They should include `*.cloudflareaccess.com/cdn-cgi/access/callback` and `https://auth.charif-labs.tech/*`.
-   **Keycloak Hostnames**: Ensure `KC_HOSTNAME` and `KC_HOSTNAME_ADMIN` in Keycloak's Docker Compose environment variables are correctly set to `https://auth.charif-labs.tech` and `https://keycloak-admin.charif-labs.tech` respectively.

### "This site can't be reached" or "ERR_TUNNEL_CONNECTION_FAILED"

This indicates an issue with the Cloudflare Tunnel or the Docker service:

-   **Check `cloudflared` Logs**: Review the logs of the `cloudflared-tunnel` container (`sudo docker logs cloudflared-tunnel --follow`) for connection errors.
-   **Verify Ingress Rules**: Ensure the `hostname` and `service` mappings in `terraform/ingress.tf` are correct and match your Docker service names and ports. For example:
    ```terraform
    {
      hostname = "wazuh.${var.domain_name}"
      service  = "https://sovereign-stack-wazuh.dashboard-1:5601" # Note HTTPS for Wazuh Dashboard
      origin_request = {
        no_tls_verify = true # Only if using self-signed certs for internal Docker communication
      }
    }
    ```

---

**Next Step:** [08 — GitHub Actions CI/CD](08-GitHub-Actions-CI-CD.md)
