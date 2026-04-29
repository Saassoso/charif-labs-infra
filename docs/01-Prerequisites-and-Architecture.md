# 01 — Prerequisites & Architecture

> Before touching any code, make sure you have the accounts, hardware, and software listed below. This will save hours of debugging later.

---

## 1.1 Cloudflare Requirements

You need a **Cloudflare account** with the following already configured:

| Requirement | Where to Find It | Used In |
|-------------|------------------|---------|
| **Domain** registered & DNS active on Cloudflare | `dash.cloudflare.com` → select domain | `terraform/variables.tf` (default: `charif-labs.tech`) |
| **Account ID** | Cloudflare Dashboard → right sidebar of domain overview | `terraform/terraform.tfvars` → `cloudflare_account_id` |
| **Zone ID** | Cloudflare Dashboard → right sidebar of domain overview | `terraform/terraform.tfvars` → `cloudflare_zone_id` |
| **API Token** | `My Profile` → `API Tokens` → `Create Token` → Use "Edit zone DNS" template, add `Zone:Read` and `DNS:Edit` for your zone | `terraform/terraform.tfvars` → `cloudflare_api_token` |

### How to Create a Cloudflare API Token (Step-by-Step)

1. Log in to [dash.cloudflare.com](https://dash.cloudflare.com).
2. Click your **profile icon** (top-right) → `My Profile`.
3. Go to the **`API Tokens`** tab.
4. Click **`Create Token`**.
5. Use the **"Edit zone DNS"** template, or configure manually:
   - **Zone:Read** — Include → Specific zone → `charif-labs.tech`
   - **DNS:Edit** — Include → Specific zone → `charif-labs.tech`
   - **Account:Read** — Include → All accounts
6. Click **Continue to summary** → **Create Token**.
7. **Copy the token immediately** — Cloudflare shows it only once.

---

## 1.2 Hardware & Host Requirements

### Minimum Specs for the Docker Host

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| **CPU** | 4 cores | 6+ cores |
| **RAM** | 8 GB | 16 GB |
| **Disk** | 50 GB SSD | 100 GB SSD |
| **OS** | Ubuntu 22.04 LTS | Ubuntu 24.04 LTS |
| **Network** | Outbound HTTPS (443) only | Same (no inbound ports required!) |

> **Key Point:** Because we use Cloudflare Tunnels, the host does **NOT** need public IP exposure. Outbound HTTPS is enough.

---

## 1.3 Required Software on the Host

Install all of these before proceeding:

### Docker & Docker Compose

```bash
# Update package index
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add the Docker APT repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine + Compose plugin
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verify
sudo docker --version
sudo docker compose version
```

### Terraform CLI

```bash
# Install hashicorp/keyring and Terraform
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update && sudo apt install -y terraform

# Verify
terraform -version
```

Required: **Terraform ≥ 1.5.0**

### Ansible (for Windows endpoint management)

```bash
sudo apt install -y ansible
ansible --version
```

Optional: `pywinrm` for Windows remote management:
```bash
pip3 install pywinrm
```

---

## 1.4 Gmail Address for Email Routing

The Terraform configuration sets up a **catch-all email rule**. Any email sent to `*@charif-labs.tech` will be forwarded to a Gmail inbox.

1. Have a Gmail address ready (e.g. `tisamplework@gmail.com`).
2. You will confirm it inside Cloudflare during the first apply (Cloudflare sends a verification email).

---

## 1.5 Architecture Decisions

### Why Cloudflare Zero Trust Tunnel?

| Traditional Hosting | Cloudflare Tunnel |
|---------------------|-------------------|
| Open ports 80/443 on firewall | Zero inbound ports |
| DDoS exposure | DDoS protection at edge |
| Static IP required | Works behind NAT / CGNAT |
| Manual certificate management | Automatic TLS (full strict) |

### Why Keycloak over Authentik?

This project uses **Keycloak** as the central IdP. It provides:
- Full OIDC / SAML support
- Fine-grained role mapping (`ztna_role`, `groups`)
- Self-hosted sovereignty (no third-party IdP dependency)
- Break-glass admin access independent of Cloudflare

### Why Wazuh?

Wazuh is an open-source XDR/SIEM platform. The stack includes:
- **Manager** — collects logs & events from agents
- **Indexer** — OpenSearch backend for storage & search
- **Dashboard** — visualizes alerts, compliance, and inventory

---

## 1.6 Network Topology

```
Internet
   │
   ▼
┌─────────────────────────────────────────┐
│         Cloudflare Edge Network         │
│   (DDoS, WAF, Zero Trust Access)        │
└─────────────┬───────────────────────────┘
              │ Tunnel (outbound HTTPS)
              ▼
┌─────────────────────────────────────────┐
│          Docker Host (Linux)            │
│  ┌──────────────┐  ┌─────────────────┐  │
│  │ cloudflared  │──│ sovereign_net   │  │
│  │   tunnel     │  │ (bridge)        │  │
│  └──────────────┘  └─────┬─────┬─────┘  │
│                          │     │         │
│              ┌───────────┘     └───────┐ │
│              ▼                         ▼ │
│        ┌──────────┐            ┌────────┐│
│        │ Keycloak │            │ Wazuh  ││
│        │ Postgres │            │ Stack  ││
│        └──────────┘            └────────┘│
│                                ┌────────┐│
│                                │Portainer││
│                                └────────┘│
└─────────────────────────────────────────┘
              │
              ▼ WinRM (internal LAN)
┌─────────────────────────────────────────┐
│      Windows Endpoints (Agents)         │
│     Wazuh Agent + Sysmon (EDR)          │
└─────────────────────────────────────────┘
```

### Internal Service Ports (inside Docker)

| Service | Internal Hostname | Port | Notes |
|---------|-------------------|------|-------|
| Keycloak | `keycloak-server` | `8080` | Proxied by Cloudflare |
| PostgreSQL | `keycloak-db` | `5432` | Internal only |
| Portainer | `portainer` | `9000` | Proxied by Cloudflare |
| Wazuh Dashboard | `wazuh.dashboard` | `5601` | Mapped to host 443 |
| Wazuh Manager | `wazuh.manager` | `55000` | Internal API |
| Wazuh Indexer | `wazuh.indexer` | `9200` | Internal only |

---

## 1.7 Checklist Before Phase 2

- [ ] Cloudflare domain is active and DNS-only or proxied
- [ ] Account ID, Zone ID, and API Token copied to a safe place
- [ ] Linux host has Docker + Docker Compose installed
- [ ] Terraform ≥ 1.5.0 installed
- [ ] Ansible installed (if managing Windows endpoints)
- [ ] Gmail address ready for email routing
- [ ] Host meets minimum specs (RAM ≥ 8 GB)

---

**Next Step:** [02 — Terraform Cloudflare Setup](02-Terraform-Cloudflare-Setup.md)
