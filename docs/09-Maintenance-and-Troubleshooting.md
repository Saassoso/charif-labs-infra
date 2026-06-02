# 09 — Maintenance and Troubleshooting

> This guide covers common maintenance tasks, troubleshooting steps for typical issues, and important security considerations for your Sovereign Security Stack.

---

## 9.1 General Docker Maintenance

### Viewing Container Status

```bash
cd docker/
sudo docker compose ps
```

This command shows all containers defined in `docker-compose.yml` and their current status (running, exited, restarting).

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/09-docker-compose-ps.png`
> **Description:** Terminal output of `sudo docker compose ps` showing all containers as `running` and `healthy`.

### Viewing Container Logs

For any container that is restarting or behaving unexpectedly, check its logs:

```bash
sudo docker logs <container_name> --tail 100 # View last 100 lines
sudo docker logs <container_name> --follow   # Stream live logs
```

Replace `<container_name>` with the actual name from `docker compose ps` (e.g., `cloudflared-tunnel`, `keycloak-server`).

### Restarting Services

-   **Individual Stack**: Navigate to the specific application directory (e.g., `docker/2-applications/security`) and run `sudo docker compose restart`.
-   **Entire Stack**: From the root `docker/` directory, run `sudo docker compose restart`.

### Updating Docker Images

To update all services to their latest configured image versions:

```bash
cd docker/
sudo docker compose pull                 # Pulls new images
sudo docker compose up -d --remove-orphans # Recreates containers with new images and removes old ones
```

---

## 9.2 Terraform State Management

### Backing Up Terraform State

The `terraform.tfstate` file is critical. It maps your Cloudflare resources to your Terraform configuration. **Back it up regularly and securely.**

```bash
cd terraform/
cp terraform.tfstate terraform.tfstate.backup.$(date +%Y%m%d%H%M%S)
```

> ⚠️ **Never commit `terraform.tfstate` to Git.** It contains sensitive data and is already in `.gitignore`.

### Re-applying Terraform Configuration

If you make changes to your `.tf` files or `terraform.tfvars`, always re-apply:

```bash
cd terraform/
terraform plan
terraform apply
```

---

## 9.3 Keycloak Maintenance

### Admin Console Access

-   **URL**: `https://keycloak-admin.charif-labs.tech`
-   **Credentials**: Admin user and password defined in `docker/2-applications/identity/.env` (and configured in Keycloak).

### Backup Keycloak Database

To back up the PostgreSQL database used by Keycloak:

```bash
sudo docker exec keycloak-db pg_dump -U keycloak keycloak > keycloak_backup_$(date +%Y%m%d%H%M%S).sql
```

**Restore (use with caution!):**

```bash
sudo docker exec -i keycloak-db psql -U keycloak keycloak < keycloak_backup.sql
```

---

## 9.4 Wazuh Maintenance

### Dashboard Access

-   **URL**: `https://wazuh.charif-labs.tech`
-   **Paste Credentials**: `admin` / `SecretPassword` (That is already updated [Phase 5](05-Wazuh-XDR-Deployment.md)).

### Checking Indexer Health

If the Dashboard is slow or showing errors, check the health of the Wazuh Indexer (OpenSearch):

```bash
# From the Docker host
curl -k -u admin:SecretPassword https://localhost:9200/_cluster/health?pretty
```

Look for `"status": "green"` or `"status": "yellow"`.

### Agent Status

Check agent connectivity and activity in the Wazuh Dashboard under `Agents`.

---

## 9.5 HashiCorp Vault Maintenance

### Accessing Vault UI

Vault is bound to localhost. Access it via SSH port forwarding:

```bash
ssh -L 8200:localhost:8200 user@your-docker-host-ip
# Then open http://localhost:8200 in your local browser
```

### Unsealing Vault

After a restart or power loss, Vault may enter a sealed state. You will need to unseal it using the unseal keys generated during its initial setup. (This project assumes a basic development setup; for production, explore auto-unseal options like KMS).

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/09-vault-unseal.png`
> **Description:** Vault UI showing the unseal keys input fields.

---

## 9.6 Break-Glass Procedures

In a critical situation (e.g., Keycloak is down, Cloudflare Access is misconfigured), you might need emergency access.

### Cloudflare Zero Trust Bypass

If Cloudflare Access is preventing all access:

1.  **Temporarily Disable Access Policies**: In the Cloudflare Dashboard, go to `Zero Trust` → `Access` → `Applications`. Find the problematic application and temporarily disable its policies or switch the decision to `Bypass`.
2.  **SSH Direct to Host**: If you still have SSH access to your Docker host, you can directly access services bound to localhost or the Docker network (e.g., Keycloak on port `8080`, Portainer on `9000`) via `curl` or `ssh` port forwarding without Cloudflare in the loop.

### Keycloak Master Admin Console

-   The `keycloak-admin.charif-labs.tech` application has a policy that allows access based on the `it-admin` group OR a specific `admin_email` from `terraform.tfvars`. If your regular `it-admin` group access fails, try logging in with the `admin_email` user if it's separate.

### Docker Socket Access

-   **Portainer**: If Portainer is inaccessible, you can manage Docker directly via the CLI on the Docker host. Portainer itself runs with access to `/var/run/docker.sock`, which grants it full control.

---

## 9.7 Important Security Reminders

-   **Rotate Secrets**: Regularly rotate all secrets (Keycloak passwords, Cloudflare API tokens, Vault root tokens/unseal keys, n8n credentials).
-   **Least Privilege**: Ensure all service accounts and users have only the minimum necessary permissions.
-   **Monitor Logs**: Actively monitor Wazuh alerts, container logs, and system logs for suspicious activity.
-   **Keep Software Updated**: Regularly update Docker images and underlying OS packages.
-   **Firewall the Docker Host**: Although Cloudflare Tunnel eliminates inbound port requirements, ensure your Docker host's local firewall (`ufw`, `firewalld`) is configured to restrict outbound traffic to only what's necessary.
-   **Secure SSH**: Harden SSH access to your Docker host (key-based auth, disable root login, rate limiting).

---

**End of Documentation**
