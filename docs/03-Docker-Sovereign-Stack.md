# 03 — Docker Sovereign Stack

> This phase launches the entire containerized platform: Keycloak, Cloudflared, Portainer, Vault, n8n, Wazuh, Prometheus, and Grafana. All services share a single Docker bridge network named `sovereign_net`.

---

## 3.1 Prerequisites Check

Before proceeding, confirm:
- [ ] Docker Engine is running: `sudo systemctl status docker`
- [ ] Docker Compose plugin works: `sudo docker compose version`
- [ ] You have the **Tunnel Token** from [02 — Terraform Cloudflare Setup](02-Terraform-Cloudflare-Setup.md)
- [ ] Linux host has at least **8 GB RAM** free (16 GB recommended)

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/03-docker-status.png`
> **Description:** Terminal showing `sudo systemctl status docker` output indicating Docker is active (running).

---

## 3.2 Repository Layout (Docker Side)

```
docker/
├── docker-compose.yml              # Orchestrator — includes all stacks + network
├── 📂 1-foundation/          # Base infrastructure services
│   ├── cloudflared/
│   │   ├── .env                    # (Optional: TUNNEL_TOKEN if not using env export)
│   │   └── docker-compose.yml    # Cloudflare Tunnel daemon
│   └── portainer/
│       └── docker-compose.yml    # Portainer CE (Docker UI)
└── 📂 2-applications/        # Business logic services
    ├── identity/
    │   ├── .env                    # (CREATE THIS — Keycloak secrets)
    │   └── docker-compose.yml    # Keycloak + PostgreSQL
    ├── secrets/
    │   ├── vault.hcl                 # Vault server configuration
    │   └── docker-compose.yml    # HashiCorp Vault
    ├── automation/
    │   ├── .env                    # (Optional: n8n basic auth credentials)
    │   └── docker-compose.yml    # n8n (workflow automation)
    ├── security/
    │   └── docker-compose.yml    # Wazuh (Manager + Indexer + Dashboard)
    └── observability/
        ├── prometheus.yml          # Prometheus scrape configuration
        └── docker-compose.yml    # Prometheus + Grafana + Node Exporter
```

The **master compose** (`docker/docker-compose.yml`) uses `include:` to import all sub-files and defines the shared `sovereign_net` network once. This keeps each application stack modular.

---

## 3.3 Create the Shared Network

Even though the master `docker-compose.yml` defines `sovereign_net`, it's a good practice to create it manually first to ensure it's external and persistent:

```bash
docker network create sovereign_net
```

Verify the network exists:
```bash
docker network inspect sovereign_net
```

You should see a bridge network with no containers yet.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/03-docker-network-inspect.png`
> **Description:** Terminal output of `docker network inspect sovereign_net` showing its details.

---

## 3.4 Configure Application Secrets & Environment Files

Create the necessary `.env` files for each application stack. **These files should never be committed to Git.**

### Keycloak Secrets (`docker/2-applications/identity/.env`)

This file holds the database and admin passwords for Keycloak. Generate strong, random passwords:

```bash
cat > docker/2-applications/identity/.env << 'EOF'
KC_DB_PASSWORD=$(openssl rand -base64 32)
KC_ADMIN_PASSWORD=$(openssl rand -base64 32)
EOF
```

View the generated values and save them in your password manager:
```bash
cat docker/2-applications/identity/.env
```

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/03-keycloak-env.png`
> **Description:** Terminal showing the content of `docker/2-applications/identity/.env` with passwords redacted.

### n8n Basic Auth (Optional: `docker/2-applications/automation/.env`)

If you want to override the default n8n basic authentication credentials, create this file:

```bash
cat > docker/2-applications/automation/.env << 'EOF'
N8N_USER=your_n8n_username
N8N_PASSWORD=your_n8n_password
EOF
```

By default, `N8N_USER` is `admin` and `N8N_PASSWORD` is `SovereignStack_2026!`. It's recommended to change these.

### Cloudflared Tunnel Token (Optional: `docker/1-foundation/cloudflared/.env`)

While you can export `TUNNEL_TOKEN` in your shell, for persistence and automation, you can place it in an `.env` file for the `cloudflared` service:

```bash
cat > docker/1-foundation/cloudflared/.env << 'EOF'
TUNNEL_TOKEN="paste-your-base64-token-here"
EOF
```

Replace `"paste-your-base64-token-here"` with the output from `terraform output -raw cloudflare_zero_trust_tunnel_cloudflared_token` in Phase 2.

---

## 3.5 Launch the Entire Stack

Navigate to the root `docker/` directory and start all services:

```bash
cd docker/
sudo docker compose --env-file ./2-applications/identity/.env \
                     --env-file ./2-applications/automation/.env \
                     --env-file ./1-foundation/cloudflared/.env \
                     up -d
```

> 💡 **Explanation of `--env-file`:** We explicitly pass the environment files for each stack. This ensures that sensitive variables are loaded correctly and isolates them to their respective services if not all are needed. Adjust the `--env-file` paths if you created fewer `.env` files (e.g., if you only used the Keycloak one).

### What Happens

1. Docker creates all defined volumes (`keycloak_database`, `n8n_data`, etc.).
2. Pulls images for all services (PostgreSQL, Keycloak, Cloudflared, Portainer, Vault, n8n, Wazuh, Prometheus, Grafana).
3. Starts containers in dependency order (e.g., PostgreSQL before Keycloak).
4. Connects all containers to the `sovereign_net` bridge network.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/03-docker-compose-up.png`
> **Description:** Terminal showing the `docker compose up -d` command output, indicating containers are created and started.

---

## 3.6 Verify Container Status

Check if all containers are running and healthy:

```bash
sudo docker compose ps
```

Expected output (all `running` and `healthy`):

```
NAME                                IMAGE                                    STATUS              PORTS
cloudflared-tunnel                  cloudflare/cloudflared:latest            Up X seconds        
keycloak-db                         postgres:15                              Up X seconds        5432/tcp
keycloak-server                     quay.io/keycloak/keycloak:latest         Up X seconds        8080/tcp
portainer                           portainer/portainer-ce:latest            Up X seconds        9000/tcp
core_vault                          hashicorp/vault:latest                   Up X seconds        127.0.0.1:8200->8200/tcp
app-automation-n8n-1                n8nio/n8n:latest                         Up X seconds        127.0.0.1:5678->5678/tcp
sovereign-stack-wazuh.manager-1     wazuh/wazuh-manager:4.14.4               Up X seconds        0.0.0.0:1514->1514/tcp, 0.0.0.0:1515->1515/tcp, 514/udp, 0.0.0.0:55000->55000/tcp
sovereign-stack-wazuh.indexer-1     wazuh/wazuh-indexer:4.14.4               Up X seconds        9200/tcp
sovereign-stack-wazuh.dashboard-1   wazuh/wazuh-dashboard:4.14.4             Up X seconds        0.0.0.0:443->5601/tcp
app-observability-prometheus-1      prom/prometheus:latest                   Up X seconds        0.0.0.0:9090->9090/tcp
app-observability-grafana-1         grafana/grafana:latest                   Up X seconds        0.0.0.0:3000->3000/tcp
app-observability-node-exporter-1   prom/node-exporter:latest                Up X seconds        0.0.0.0:9100->9100/tcp
```

If any container shows `Restarting` or `Exited`, check its logs immediately:
```bash
sudo docker logs <container_name> --tail 50
```

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/03-docker-compose-ps.png`
> **Description:** Terminal output of `sudo docker compose ps` showing all containers running.

---

## 3.7 Initial Service Access & Verification

Give services a few minutes to fully start up and initialize.

### Cloudflared Tunnel
```bash
sudo docker logs cloudflared-tunnel --tail 20
```
Look for messages indicating successful connection to Cloudflare edge:
```
INF Connection registered ... location=<your-nearest-colo>
INF Connected to ...
```

### Portainer
Browse to: `https://mgmt.charif-labs.tech`
On your first visit, Portainer will prompt you to create an admin password. Complete the setup.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/03-portainer-initial-setup.png`
> **Description:** Portainer web UI showing the initial admin password setup screen.

### Keycloak
Browse to: `https://auth.charif-labs.tech`
You should see the Keycloak login page. This confirms the service is running and accessible via the tunnel.

### Wazuh Dashboard
Browse to: `https://wazuh.charif-labs.tech`
> ⚠️ Wazuh takes 2–5 minutes to initialize on first boot (index creation). You might see "Wazuh dashboard server is not ready yet" initially. Be patient.

### n8n
Browse to: `https://n8n.charif-labs.tech`
If you configured basic authentication, you will be prompted for credentials.

### Grafana
Browse to: `https://grafana.charif-labs.tech`
Default login: `admin` / `admin` (change this immediately in `docker/2-applications/observability/docker-compose.yml` and restart).

### HashiCorp Vault
Vault is **not exposed externally**. Access it by SSH tunneling:
```bash
ssh -L 8200:localhost:8200 user@your-docker-host-ip
```
Then, in your local browser, navigate to: `http://localhost:8200`

---

## 3.8 Resource Monitoring

On a constrained host, services like Wazuh or Vault may experience out-of-memory (OOM) issues. Monitor resource usage:

```bash
# Live container stats
sudo docker stats

# Specific container memory
sudo docker stats sovereign-stack-wazuh.indexer-1
```

If the Wazuh indexer is killed, increase the host RAM or reduce its Java heap in `docker/2-applications/security/docker-compose.yml`:
```yaml
# docker/2-applications/security/docker-compose.yml
environment:
  - "OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m"  # Default is 1g
```

---

## 3.9 Restarting & Updating Stacks

### Restarting Individual Application Stacks

You don't always need to restart everything. Navigate to the specific application directory and restart:

```bash
# Restart only Keycloak (and its database)
cd docker/2-applications/identity
sudo docker compose restart

# Restart only Wazuh
cd docker/2-applications/security
sudo docker compose restart

# Restart only n8n
cd docker/2-applications/automation
sudo docker compose restart

# Full stack restart (from the main docker/ directory)
cd docker/
sudo docker compose restart
```

### Updating Images

To update all images to their latest tags and recreate containers:

```bash
cd docker/
sudo docker compose pull
sudo docker compose up -d --remove-orphans # --remove-orphans removes containers for services no longer defined
```

---

## 3.10 Troubleshooting

### Cloudflared: "Token not provided"
```
ERR Failed to serve quic connection error="Token not provided"
```
**Fix:** The `TUNNEL_TOKEN` environment variable is empty or incorrect. Re-export it or verify `docker/1-foundation/cloudflared/.env` and restart Cloudflared:
```bash
export TUNNEL_TOKEN="..."
sudo -E docker compose -f docker/1-foundation/cloudflared/docker-compose.yml up -d
```

### Keycloak: Database not reachable
```
FATAL: database "keycloak" does not exist
```
**Fix:** This usually means the Keycloak PostgreSQL volume is corrupted or not properly initialized. Wipe the Keycloak volume and re-create:
```bash
sudo docker compose -f docker/2-applications/identity/docker-compose.yml down
sudo docker volume rm keycloak_database
sudo docker compose -f docker/2-applications/identity/docker-compose.yml up -d
```

### Portainer: Cannot connect to Docker endpoint
**Fix:** Portainer needs access to the Docker socket. Verify the bind mount in `docker/1-foundation/portainer/docker-compose.yml`:
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```
If running Docker as root but Portainer as non-root, adjust socket permissions or run Portainer as root (not recommended).

### Wazuh Dashboard: "Wazuh dashboard server is not ready yet"
**Fix:** Wait 5 minutes. If still failing, check indexer health:
```bash
sudo docker logs sovereign-stack-wazuh.indexer-1 --tail 30
```
Ensure the indexer is green by checking its internal health API (you might need `curl -k` due to self-signed certs):
```bash
curl -k -u admin:SecretPassword https://localhost:9200/_cluster/health
```
(Replace `SecretPassword` with the actual password if changed).

---

## 3.11 Docker Compose File Reference

### Master Compose (`docker/docker-compose.yml`)
```yaml
include:
  - 1-foundation/cloudflared/docker-compose.yml
  - 1-foundation/portainer/docker-compose.yml
  - 2-applications/identity/docker-compose.yml
  - 2-applications/secrets/docker-compose.yml
  - 2-applications/automation/docker-compose.yml
  - 2-applications/security/docker-compose.yml
  - 2-applications/observability/docker-compose.yml

networks:
  sovereign_net:
    external: true # Use the manually created network
```

> **Design note:** Using `include:` keeps each stack modular. You can comment out an `include` line to disable a stack entirely without modifying its internal `docker-compose.yml`.

---

**Next Step:** [04 — Keycloak Identity Provider](04-Keycloak-Identity-Provider.md)
