# 03 — Docker Sovereign Stack

> This phase launches the entire containerized platform: Keycloak, Cloudflared, Portainer, and Wazuh. All services share a single Docker bridge network named `sovereign_net`.

---

## 3.1 Prerequisites Check

Before proceeding, confirm:
- [ ] Docker Engine is running: `sudo systemctl status docker`
- [ ] Docker Compose plugin works: `sudo docker compose version`
- [ ] You have the **Tunnel Token** from [02 — Terraform Cloudflare Setup](02-Terraform-Cloudflare-Setup.md)
- [ ] Linux host has at least **8 GB RAM** free

---

## 3.2 Repository Layout (Docker Side)

```
docker/
├── docker-compose.yml              # Master file — includes all stacks + network
├── core-identity/
│   ├── keycloak/
│   │   ├── docker-compose.yml      # Postgres + Keycloak
│   │   └── .env                    # (CREATE THIS — secrets)
│   └── cloudflared/
│       └── docker-compose.yml      # Cloudflared daemon
├── management/
│   └── portainer/
│       └── docker-compose.yml      # Portainer CE
└── wazuh/
    └── docker-compose.yml          # Manager + Indexer + Dashboard
```

The **master compose** uses `include:` to import all sub-files and defines the shared `sovereign_net` network once.

---

## 3.3 Create the Shared Network

Although the master `docker-compose.yml` defines `sovereign_net`, create it manually first to be safe:

```bash
docker network create sovereign_net
```

Verify:
```bash
docker network inspect sovereign_net
```

You should see a bridge network with no containers yet.

---

## 3.4 Configure Keycloak Secrets

Create the `.env` file for Keycloak:

```bash
cat > docker/core-identity/keycloak/.env << 'EOF'
KC_DB_PASSWORD=$(openssl rand -base64 32)
KC_ADMIN_PASSWORD=$(openssl rand -base64 32)
EOF
```

View the generated values (save them in your password manager):
```bash
cat docker/core-identity/keycloak/.env
```

> 🔒 This file is `.gitignore`-d. Never commit it.

---

## 3.5 Configure the Tunnel Token

Set the `TUNNEL_TOKEN` environment variable so Cloudflared can authenticate:

```bash
export TUNNEL_TOKEN="paste-your-base64-token-here"
```

To make it persistent across reboots, add it to your shell profile:
```bash
echo "export TUNNEL_TOKEN='your-token-here'" | sudo tee /etc/profile.d/cloudflare-tunnel.sh
```

---

## 3.6 Launch the Stack

```bash
cd docker/
sudo docker compose up -d
```

### What Happens

1. Docker creates all defined volumes.
2. Pulls images: `postgres:15`, `keycloak:latest`, `cloudflare/cloudflared:latest`, `portainer/portainer-ce:latest`, `wazuh/wazuh-*:4.14.4`.
3. Starts containers in dependency order.
4. Connects all containers to `sovereign_net`.

---

## 3.7 Verify Container Status

```bash
sudo docker compose ps
```

Expected output (all `running` and `healthy`):

```
NAME                  IMAGE                                    STATUS
keycloak-db           postgres:15                              Up 30 seconds
keycloak-server       quay.io/keycloak/keycloak:latest         Up 25 seconds
cloudflared-tunnel    cloudflare/cloudflared:latest            Up 20 seconds
portainer             portainer/portainer-ce:latest            Up 15 seconds
sovereign-stack-wazuh.manager-1    wazuh/wazuh-manager:4.14.4  Up 10 seconds
sovereign-stack-wazuh.indexer-1    wazuh/wazuh-indexer:4.14.4  Up 10 seconds
sovereign-stack-wazuh.dashboard-1  wazuh/wazuh-dashboard:4.14.4 Up 5 seconds
```

If any container shows `Restarting`, check logs immediately:
```bash
sudo docker logs <container_name> --tail 50
```

---

## 3.8 Service-Specific Verification

### Keycloak
```bash
# Check if Keycloak responds internally
curl -s http://localhost:8080 | head -n 5
```
Externally, browse to: `https://auth.charif-labs.tech`

### Cloudflared
```bash
sudo docker logs cloudflared-tunnel --tail 20
```
You should see:
```
INF Connection registered ... location=<your-nearest-colo>
INF Connected to ...
```

### Portainer
Browse to: `https://mgmt.charif-labs.tech`
On first visit, Portainer asks you to create an admin password.

### Wazuh Dashboard
Browse to: `https://wazuh.charif-labs.tech`
> ⚠️ Wazuh takes 2–5 minutes to initialize on first boot (index creation).

---

## 3.9 Resource Monitoring

On a constrained host, Wazuh may OOM-kill. Monitor usage:

```bash
# Live container stats
sudo docker stats

# Specific container memory
sudo docker stats sovereign-stack-wazuh.indexer-1
```

If the indexer is killed, increase the host RAM or reduce Java heap:
```yaml
# docker/wazuh/docker-compose.yml
environment:
  - "OPENSEARCH_JAVA_OPTS=-Xms512m -Xmx512m"  # Default is 1g
```

---

## 3.10 Restarting Individual Stacks

You don't always need to restart everything.

```bash
# Restart only Keycloak
cd docker/core-identity/keycloak
sudo docker compose restart

# Restart only Wazuh
cd docker/wazuh
sudo docker compose restart

# Full stack restart
cd docker/
sudo docker compose restart
```

---

## 3.11 Updating Images

```bash
cd docker/
sudo docker compose pull
sudo docker compose up -d
```

This pulls newer image tags and recreates containers with the updated code.

---

## 3.12 Troubleshooting

### Cloudflared: "Token not provided"
```
ERR Failed to serve quic connection error="Token not provided"
```
**Fix:** The `TUNNEL_TOKEN` environment variable is empty. Re-export it and restart:
```bash
export TUNNEL_TOKEN="..."
sudo -E docker compose up -d cloudflared
```

### Keycloak: Database not reachable
```
FATAL: database "keycloak" does not exist
```
**Fix:** Wipe the keycloak volume and re-create:
```bash
sudo docker compose down
sudo docker volume rm keycloak_database
sudo docker compose up -d postgresql-kc keycloak
```

### Portainer: Cannot connect to Docker endpoint
**Fix:** Portainer needs access to the Docker socket. Verify the bind mount:
```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```
If running Docker as root but Portainer as non-root, adjust socket permissions or run Portainer as root.

### Wazuh Dashboard: "Wazuh dashboard server is not ready yet"
**Fix:** Wait 5 minutes. If still failing, check indexer health:
```bash
sudo docker logs sovereign-stack-wazuh.indexer-1 --tail 30
```
Ensure the indexer is green:
```bash
curl -k -u admin:SecretPassword https://localhost:9200/_cluster/health
```

---

## 3.13 Docker Compose File Reference

### Master Compose (`docker/docker-compose.yml`)
```yaml
include:
  - core-identity/cloudflared/docker-compose.yml
  - core-identity/keycloak/docker-compose.yml
  - management/portainer/docker-compose.yml
  - wazuh/docker-compose.yml

networks:
  sovereign_net:
    driver: bridge
    name: sovereign_net
```

> **Design note:** Using `include:` keeps each stack modular. You can comment out an include to disable a stack entirely.

---

**Next Step:** [04 — Keycloak Identity Provider](04-Keycloak-Identity-Provider.md)
