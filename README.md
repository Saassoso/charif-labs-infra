# Sovereign Security Stack v2.0 — CHARif-LABS-INFRA

> A self-hosted, Zero-Trust Security Operations (SecOps) platform built on Docker, Terraform, and Ansible.  
> All services are exposed securely via Cloudflare Zero Trust Tunnels with Keycloak OIDC authentication.

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         CLOUDFLARE EDGE (Zero Trust)                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ auth.charif │  │wazuh.charif │  │ mgmt.charif │  │ keycloak-admin.char │ │
│  │ -labs.tech  │  │ -labs.tech  │  │ -labs.tech  │  │ if-labs.tech        │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘ │
│         └─────────────────┴─────────────────┴────────────────────┘            │
│                                   │                                          │
│                    ┌──────────────▼──────────────┐                           │
│                    │   Cloudflare Tunnel (ZTNA)  │                           │
│                    └──────────────┬──────────────┘                           │
└───────────────────────────────────┼─────────────────────────────────────────┘
                                    │
                            ┌───────▼────────┐
                            │  Cloudflared   │  ◄── Docker Container
                            │    Daemon      │
                            └───────┬────────┘
                                    │ sovereign_net (bridge)
          ┌─────────────────────────┼─────────────────────────┐
          │                         │                         │
   ┌──────▼──────┐          ┌───────▼───────┐       ┌────────▼────────┐
   │  Keycloak   │          │   Wazuh Stack │       │   Portainer CE  │
   │  (IdP/OIDC) │          │ ├─ Manager    │       │  (Docker Mgmt)  │
   │  + Postgres │          │ ├─ Indexer    │       └─────────────────┘
   └─────────────┘          │ └─ Dashboard  │
                            └───────────────┘
                                    │
                    ┌───────────────┴───────────────┐
                    │     Windows Endpoints         │
                    │  (Wazuh Agent + Sysmon)       │
                    └───────────────────────────────┘
                                    ▲
                                    │ WinRM / Ansible
```

---

## 📁 Repository Structure

```
charif-labs-infra/
├── 📂 terraform/                 # Infrastructure as Code (Cloudflare)
│   ├── main.tf                   # Tunnel + DNS records
│   ├── provider.tf               # Cloudflare provider v5.x
│   ├── variables.tf              # Input variables
│   ├── access.tf                 # Zero Trust Access Apps & Keycloak IdP
│   ├── ingress.tf                # Tunnel ingress routing rules
│   ├── email.tf                  # Email routing (catch-all)
│   ├── moved.tf                  # State migration v4 → v5
│   └── terraform.tfvars          # (SECRET — create locally)
│
├── 📂 docker/                    # Container orchestration
│   ├── docker-compose.yml        # Master compose (includes all stacks)
│   ├── 📂 core-identity/
│   │   ├── keycloak/
│   │   │   ├── docker-compose.yml
│   │   │   └── .env              # (SECRET — create locally)
│   │   └── cloudflared/
│   │       └── docker-compose.yml
│   ├── 📂 management/
│   │   └── portainer/
│   │       └── docker-compose.yml
│   └── 📂 wazuh/
│       └── docker-compose.yml    # Wazuh Manager + Indexer + Dashboard
│
├── 📂 ansible/                   # Configuration management
│   ├── inventory.ini             # (adapt to your endpoints)
│   └── 📂 exemple/               # Example playbooks
│
├── 📂 docs/                      # 📖 Step-by-step guides
│   ├── 01-Prerequisites-and-Architecture.md
│   ├── 02-Terraform-Cloudflare-Setup.md
│   ├── 03-Docker-Sovereign-Stack.md
│   ├── 04-Keycloak-Identity-Provider.md
│   ├── 05-Wazuh-XDR-Deployment.md
│   ├── 06-Ansible-Endpoint-Management.md
│   └── 07-Zero-Trust-Access-Configuration.md
│
├── .gitignore                    # Excludes .env, tfstate, .terraform
└── README.md                     # ← You are here
```

---

## 🚀 Quick Start

These are the high-level steps.  
**For detailed, copy-paste instructions, see each guide in `docs/`.**

### Phase 1 — Prerequisites
1. A domain managed by Cloudflare (e.g. `charif-labs.tech`)
2. A Linux host with Docker + Docker Compose installed
3. Terraform CLI ≥ 1.5.0
4. Ansible (for Windows endpoint management)
5. A Gmail address for email-routing catch-all

### Phase 2 — Terraform (Cloudflare IaC)
```bash
cd terraform/
terraform init
terraform plan
terraform apply
```
This creates:
- A **Cloudflare Zero Trust Tunnel**
- **DNS CNAME records** for `auth`, `wazuh`, `mgmt`, `keycloak-admin`
- **Email routing** catch-all rule
- **Zero Trust Access Applications** protected by Keycloak OIDC

> 🔑 Copy the sensitive output `cloudflare_zero_trust_tunnel_cloudflared_token` — you will need it for Docker.

### Phase 3 — Secrets & Environment Files
Create the following files **locally** (never commit them):

**`docker/core-identity/keycloak/.env`**
```bash
KC_DB_PASSWORD=<strong_random_password>
KC_ADMIN_PASSWORD=<strong_random_password>
```

**`terraform/terraform.tfvars`**
```hcl
cloudflare_account_id = "your_account_id"
cloudflare_zone_id    = "your_zone_id"
cloudflare_api_token  = "your_api_token"
keycloak_client_secret = "will_be_generated_in_keycloak"
```

### Phase 4 — Docker Stack
```bash
cd docker/
docker compose up -d
```
This starts:
- PostgreSQL database for Keycloak
- Keycloak server (`auth.charif-labs.tech`)
- Cloudflared tunnel daemon
- Portainer (`mgmt.charif-labs.tech`)
- Wazuh XDR platform (`wazuh.charif-labs.tech`)

### Phase 5 — Keycloak Configuration
1. Log in to `https://auth.charif-labs.tech/admin` (default: `akadmin`)
2. Create a **realm** named `charif-labs`
3. Create an **OIDC client** named `cloudflare-access`
4. Add the `ztna_role` user attribute and map it to a claim
5. Update `terraform.tfvars` with the generated **Client Secret**
6. Re-run `terraform apply`

### Phase 6 — Endpoint Deployment (Ansible)
```bash
cd docker/ansible/
ansible-playbook -i inventory.ini deploy_wazuh.yml
ansible-playbook -i inventory.ini configure_sysmon_wazuh.yml
```

---

## 🌐 Service Map

| Subdomain | Service | Access Control |
|-----------|---------|----------------|
| `auth.charif-labs.tech` | Keycloak SSO | Public (IdP) |
| `wazuh.charif-labs.tech` | Wazuh Dashboard | Keycloak + `it-admin` role |
| `mgmt.charif-labs.tech` | Portainer CE | Keycloak + `it-admin` role |
| `keycloak-admin.charif-labs.tech` | Keycloak Admin Console | Keycloak + `it-admin` group + specific email |

---

## 🔐 Security Model

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Edge** | Cloudflare Zero Trust Tunnel | No open inbound ports on the host |
| **Identity** | Keycloak OIDC | Centralized SSO & RBAC |
| **Access** | Cloudflare Access Applications | Per-app policies (role-based) |
| **Network** | Docker Bridge (`sovereign_net`) | Container isolation |
| **Endpoints** | Wazuh Agent + Sysmon | EDR / XDR telemetry |

---

## 📖 Documentation

Each doc is a standalone, step-by-step guide. Read them in order:

1. **[01 — Prerequisites & Architecture](docs/01-Prerequisites-and-Architecture.md)**  
   Hardware, software, and Cloudflare account requirements.

2. **[02 — Terraform Cloudflare Setup](docs/02-Terraform-Cloudflare-Setup.md)**  
   Authenticate, plan, and apply the entire Cloudflare layer.

3. **[03 — Docker Sovereign Stack](docs/03-Docker-Sovereign-Stack.md)**  
   Install Docker, create the network, and launch all services.

4. **[04 — Keycloak Identity Provider](docs/04-Keycloak-Identity-Provider.md)**  
   Realm creation, client setup, user attributes, and Cloudflare IdP mapping.

5. **[05 — Wazuh XDR Deployment](docs/05-Wazuh-XDR-Deployment.md)**  
   SSL certificates, indexer configuration, dashboard access, and agent enrollment.

6. **[06 — Ansible Endpoint Management](docs/06-Ansible-Endpoint-Management.md)**  
   WinRM configuration, inventory setup, Wazuh agent deployment, and Sysmon integration.

7. **[07 — Zero Trust Access Configuration](docs/07-Zero-Trust-Access-Configuration.md)**  
   How Access Policies work, troubleshooting loops, and break-glass access.

---

## ⚠️ Important Notes

- **Never commit secrets.** `.gitignore` already excludes `.env`, `*.tfvars`, and `terraform.tfstate`.
- **Keycloak is in `start-dev` mode.** For production, switch to `start` with proper hostname settings and a reverse-proxy certificate.
- **Wazuh default passwords** are hard-coded in `docker/wazuh/docker-compose.yml`. Rotate them before production use.
- **Cloudflare tunnel token** is base64-encoded JSON. Treat it as sensitive as an API key.
- **The `moved.tf` file** handles Terraform state migration from Cloudflare provider v4 to v5. Do not delete it if you have existing state.

---

## 🛠️ Maintenance Commands

```bash
# View all running containers
docker compose -f docker/docker-compose.yml ps

# Restart the entire stack
docker compose -f docker/docker-compose.yml restart

# View Cloudflared logs
docker logs cloudflared-tunnel --follow

# Re-apply Terraform after changing variables
terraform -chdir=terraform apply

# Scale Wazuh (if needed)
docker compose -f docker/wazuh/docker-compose.yml up -d
```

---

## 📜 License

This infrastructure template is provided as-is for educational and self-hosted security operations.  
Review and harden all default credentials before deploying to a production environment.

---

*Built with Terraform, Docker, Keycloak, Wazuh, Cloudflare Zero Trust, and Ansible.*
