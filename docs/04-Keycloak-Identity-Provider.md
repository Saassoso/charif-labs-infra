# 04 — Keycloak Identity Provider

> This phase focuses on configuring Keycloak, our central Identity Provider, and linking it with Cloudflare Zero Trust.

---

## 4.1 Initial Access to Keycloak Admin Console

After launching the Docker stack in [Phase 3](03-Docker-Sovereign-Stack.md), Keycloak should be running.

1.  Browse to the Keycloak Admin Console: `https://keycloak-admin.charif-labs.tech`
2.  You will be prompted for credentials. Use the `KC_ADMIN_PASSWORD` you generated in `docker/2-applications/identity/.env` (default username is `admin`).

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/04-keycloak-admin-login.png`
> **Description:** Keycloak Admin Console login screen.

---

## 4.2 Create the `charif-labs` Realm

Keycloak uses "realms" to isolate users, applications, and configurations.

1.  In the Admin Console, hover over "Master" in the top-left navigation.
2.  Click "Add realm".
3.  Enter `charif-labs` as the name.
4.  Click "Create".

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/04-keycloak-create-realm.png`
> **Description:** Keycloak Admin Console screen showing the "Add realm" dialog with "charif-labs" entered.

---

## 4.3 Configure the `cloudflare-access` OIDC Client

Cloudflare Zero Trust Access will act as an OpenID Connect (OIDC) client to Keycloak.

1.  Navigate to your new `charif-labs` realm (if not already there).
2.  In the left sidebar, go to `Clients`.
3.  Click "Create client".
4.  For `Client ID`, enter `cloudflare-access`.
5.  Click "Next".
6.  For `Client authentication`, enable it.
7.  For `Authorization` and `Device authorization grant`, leave them off.
8.  For `Standard flow`, `Direct access grants`, `Service accounts`, `Implicit flow`, `OIDC CIBA Grant`, `Backchannel logout`, enable them.
9.  Click "Next".
10. In the `Client details` page:
    -   `Root URL`: `https://auth.charif-labs.tech`
    -   `Home URL`: `https://auth.charif-labs.tech`
    -   `Valid redirect URIs`:
        -   `https://*.cloudflareaccess.com/cdn-cgi/access/callback`
        -   `https://auth.charif-labs.tech/*`
    -   `Valid post logout redirect URIs`:
        -   `https://*.cloudflareaccess.com/cdn-cgi/access/logout`
        -   `https://auth.charif-labs.tech/*`
    -   `Web origins`:
        -   `+` (This allows all origins for now, consider restricting in production)
11. Click "Save".

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/04-keycloak-client-creation.png`
> **Description:** Keycloak Admin Console, "Clients" section, showing the `cloudflare-access` client configuration with redirect URIs and web origins.

---

## 4.4 Retrieve the Client Secret

1.  On the `cloudflare-access` client configuration page, go to the `Credentials` tab.
2.  Copy the `Client Secret` value.

**Important:** Update this secret in your `terraform/terraform.tfvars` file.

```hcl
# terraform/terraform.tfvars
keycloak_client_secret = "YOUR_NEWLY_GENERATED_CLIENT_SECRET"
```

Then, re-run `terraform apply` from the `terraform/` directory:

```bash
cd terraform/
terraform apply
```

This updates the `cloudflare_zero_trust_access_identity_provider.keycloak_oidc` resource with the correct client secret, allowing Cloudflare to authenticate with Keycloak.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/04-keycloak-client-secret.png`
> **Description:** Keycloak Admin Console, `cloudflare-access` client, `Credentials` tab, showing the client secret.

---

## 4.5 Configure User Attributes and Mappers

To enable role-based access in Cloudflare, we need to map Keycloak user attributes to OIDC claims.

### Create `ztna_role` User Attribute

This custom attribute will be used to assign roles like `it-admin`.

1.  In the `charif-labs` realm, go to `Realm settings` → `User profile`.
2.  Click `Create attribute`.
3.  `Name`: `ztna_role`
4.  `Display name`: `ZTNA Role`
5.  `Validators`: Add `options` validator and add `it-admin` as an allowed option.
6.  Click "Save".

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/04-keycloak-ztna-role-attribute.png`
> **Description:** Keycloak Admin Console, "User profile" section, showing the `ztna_role` attribute definition with `it-admin` option.

### Create `ztna_role` OIDC Mapper

This mapper will include the `ztna_role` in the OIDC `id_token` and `access_token`.

1.  Still in the `charif-labs` realm, go to `Clients` → `cloudflare-access` → `Client Scopes` tab.
2.  Click on the `openid` client scope.
3.  Go to the `Mappers` tab.
4.  Click `Add mapper` → `User Attribute`.
5.  Configure the mapper:
    -   `Name`: `ztna_role`
    -   `User Attribute`: `ztna_role`
    -   `Token Claim Name`: `ztna_role`
    -   `Claim JSON Type`: `String`
    -   `Add to ID token`: `On`
    -   `Add to Access Token`: `On`
    -   `Add to Userinfo`: `On`
6.  Click "Save".

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/04-keycloak-ztna-role-mapper.png`
> **Description:** Keycloak Admin Console, `cloudflare-access` client scope, `Mappers` tab, showing the `ztna_role` mapper configuration.

---

## 4.6 Create Users and Groups

### Create the `it-admin` Group

1.  In the `charif-labs` realm, go to `Groups`.
2.  Click `Create group`.
3.  `Name`: `it-admin`
4.  Click "Create".

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/04-keycloak-create-group.png`
> **Description:** Keycloak Admin Console, "Groups" section, showing the `it-admin` group created.

### Create an Admin User

Create a user and assign them to the `it-admin` group and set their `ztna_role`.

1.  In the `charif-labs` realm, go to `Users`.
2.  Click `Add user`.
3.  `Username`: `admin_user` (or your preferred admin username)
4.  Set `Email verified` to `On`.
5.  Go to the `Credentials` tab for the new user, set a strong password, and toggle `Temporary` to `Off`.
6.  Go to the `Groups` tab, click `Join Group`, and select `it-admin`.
7.  Go to the `Attributes` tab, click `Add attribute`:
    -   `Key`: `ztna_role`
    -   `Value`: `it-admin`
8.  Click "Save".

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/04-keycloak-create-user.png`
> **Description:** Keycloak Admin Console, "Users" section, showing a new user with `it-admin` group and `ztna_role` attribute.

---

## 4.7 Verify Cloudflare IdP Connection

1.  In the Cloudflare Dashboard, go to `Zero Trust` → `Access` → `Identity Providers`.
2.  Confirm that the `Keycloak` IdP (created by Terraform) shows a green checkmark indicating a healthy connection.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/04-cloudflare-idp-status.png`
> **Description:** Cloudflare Zero Trust Dashboard, "Identity Providers" section, showing the Keycloak OIDC provider as healthy.

---

**Next Step:** [05 — Wazuh XDR Deployment](05-Wazuh-XDR-Deployment.md)
