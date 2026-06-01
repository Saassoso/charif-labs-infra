# Sovereign Security Stack v2.0 — CHARif-LABS-INFRA

> A self-hosted, Zero-Trust Security Operations (SecOps) platform built on Docker, Terraform, and Ansible.  
> All services are exposed securely via Cloudflare Zero Trust Tunnels with Keycloak OIDC authentication.

---

## 🏗️ Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                         CLOUDFLARE EDGE (Zero Trust)                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ auth.charif │  │n8n.charif   │  │ mgmt.charif │  │ keycloak-admin.char │  │
│  │ -labs.tech  │  │ -labs.tech  │  │ -labs.tech  │  │ if-labs.tech        │  │
│  ├─────────────┤  ├─────────────┤  ├─────────────┤  ├─────────────────────┤  │
│  │ wazuh.charif│  │grafana.chari│  │ iam.charif  │  │ vault (local only)  │  │
│  │ -labs.tech  │  │ f-labs.tech │  │ -labs.tech  │  │                     │  │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────────────────────┘  │
│         └─────────────────┴─────────────────┴────────────────────┘           │
│                                   │                                          │
│                    ┌──────────────▼──────────────┐                           │
│                    │   Cloudflare Tunnel (ZTNA)  │                           │
│                    └──────────────┬──────────────┘                           │
└───────────────────────────────────┼──────────────────────────────────────────┘
                                    │
                            ┌───────▼────────┐
                            │  Cloudflared   │  ◄── Docker Container (Foundation)
                            │    Daemon      │
                            └───────┬────────┘
                                    │ sovereign_net (bridge)
          ┌─────────────────────────┼─────────────────────────┐
          │                         │                         │
   ┌──────▼──────┐          ┌────────▼───────┐       ┌────────▼────────┐
   │  Keycloak   │          │  Wazuh Stack   │       │   Portainer CE  │
   │  (IdP/OIDC) │          │  ├─ Manager    │       │  (Docker Mgmt)  │
   │  + Postgres │          │  ├─ Indexer    │       └─────────────────┘
   └─────────────┘          │  └─ Dashboard  │
                            └────────────────┘
   ┌──────────────┐         ┌───────────────┐         ┌─────────────────┐
   │     n8n      │         │    Grafana    │         │  HashiCorp Vault│
   │ (Automation) │         │  + Prometheus │         │  (Secrets Mgmt) │
   └──────────────┘         │  + Node Exp.  │         └─────────────────┘
                            └───────────────┘
                                    ▲
                                    │ SSH / Ansible
┌───────────────────────────────────┴─────────────────────────────────────────┐
│                         Docker Host (Linux)                                 │
│              Managed via Ansible playbooks for baseline hardening           │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Repository Structure

```
charif-labs-infra/
├── 📂 terraform/                 # Infrastructure as Code (Cloudflare)
│   ├── main.tf                   # Tunnel + DNS records + verification TXT
│   ├── provider.tf               # Cloudflare provider v5.x
│   ├── variables.tf              # Input variables
│   ├── access.tf                 # Zero Trust Access Apps & Keycloak IdP
│   ├── ingress.tf                # Tunnel ingress routing rules
│   ├── email.tf                  # Email routing (catch-all)
│   ├── rules.tf                  # Redirect rules (iam → keycloak-admin)
│   ├── tcp.tf                    # Wazuh agent/auth DNS records
│   ├── moved.tf                  # State migration v4 → v5
│   └── terraform.tfvars          # (SECRET — create locally)
│
├── 📂 docker/                    # Container orchestration
│   ├── docker-compose.yml        # Orchestrator — includes all stacks
│   ├── 📂 1-foundation/          # Base infrastructure services
│   │   ├── cloudflared/
│   │   │   └── docker-compose.yml    # Cloudflare Tunnel daemon
│   │   └── portainer/
│   │       └── docker-compose.yml    # Portainer CE (Docker UI)
│   └── 📂 2-applications/        # Business logic services
│       ├── identity/
│       │   └── docker-compose.yml    # Keycloak + PostgreSQL
│       ├── secrets/
│       │   └── docker-compose.yml    # HashiCorp Vault
│       ├── automation/
│       │   └── docker-compose.yml    # n8n (workflow automation)
│       ├── security/
│       │   └── docker-compose.yml    # Wazuh (Manager + Indexer + Dashboard)
│       └── observability/
│           └── docker-compose.yml    # Prometheus + Grafana + Node Exporter
│
├── 📂 ansible/                   # Docker-host configuration management
│   ├── inventory.ini             # (adapt to your Docker host)
│   └── 📂 exemple/               # Example playbooks for host baseline
│
├── 📂 docs/                      # 📖 Step-by-step guides
│   ├── 01-Prerequisites-and-Architecture.md
│   ├── 02-Terraform-Cloudflare-Setup.md
│   ├── 03-Docker-Sovereign-Stack.md
│   ├── 04-Keycloak-Identity-Provider.md
│   ├── 05-Wazuh-XDR-Deployment.md
│   ├── 06-Ansible-Docker-Host-Management.md
│   ├── 07-Zero-Trust-Access-Configuration.md
│   ├── 08-GitHub-Actions-CI-CD.md
│   └── 09-Maintenance-and-Troubleshooting.md
│
├── .github/workflows/
│   └── pipeline.yml              # CI/CD: security scan → validate → tag → deploy
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
4. Ansible (for Docker host hardening & maintenance)
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
- **DNS CNAME records** for all subdomains
- **Email routing** catch-all rule
- **Zero Trust Access Applications** protected by Keycloak OIDC
- **Redirect rules** (e.g. `iam.` → Keycloak admin console)

> 🔑 Copy the sensitive output `cloudflare_zero_trust_tunnel_cloudflared_token` — you will need it for Docker.

### Phase 3 — Secrets & Environment Files
Create the following files **locally** (never commit them):

**`docker/core-identity/keycloak/.env`** (or `docker/2-applications/identity/.env`)
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
docker network create sovereign_net
docker compose up -d
```
This starts:
- **Cloudflared** tunnel daemon (foundation)
- **Portainer** CE for Docker management (foundation)
- **PostgreSQL** database for Keycloak (identity)
- **Keycloak** server (identity)
- **HashiCorp Vault** for secrets management (secrets)
- **n8n** workflow automation (automation)
- **Wazuh** XDR platform (security)
- **Prometheus + Grafana + Node Exporter** (observability)

### Phase 5 — Keycloak Configuration
1. Log in to `https://auth.charif-labs.tech/admin`
2. Create a **realm** named `charif-labs`
3. Create an **OIDC client** named `cloudflare-access`
4. Add the `ztna_role` user attribute and map it to a claim
5. Update `terraform.tfvars` with the generated **Client Secret**
6. Re-run `terraform apply`

### Phase 6 — Ansible Docker-Host Hardening
```bash
cd ansible/
ansible-playbook -i inventory.ini exemple/NTP_Installed.yaml
# Adapt and extend playbooks for your Docker host baseline
```

> Ansible in this project targets the **Linux Docker host** for baseline hardening, maintenance, and package management — not Windows endpoints.

### Phase 7 — Verify Zero Trust Access
Browse to each service and confirm Cloudflare Access prompts for Keycloak login:
- `https://wazuh.charif-labs.tech`
- `https://mgmt.charif-labs.tech`
- `https://grafana.charif-labs.tech`

---

## 🌐 Service Map

| Subdomain | Service | Stack | Access Control |
|-----------|---------|-------|----------------|
| `auth.charif-labs.tech` | Keycloak SSO | Identity | Public (IdP endpoint) |
| `keycloak-admin.charif-labs.tech` | Keycloak Admin Console | Identity | Keycloak + `it-admin` group + admin email |
| `iam.charif-labs.tech` | Shortcut to Keycloak Admin | Identity | 301 Redirect to `keycloak-admin` path |
| `wazuh.charif-labs.tech` | Wazuh Dashboard | Security | Keycloak + `it-admin` role |
| `n8n.charif-labs.tech` | n8n Automation | Automation | Keycloak + `it-admin` role |
| `grafana.charif-labs.tech` | Grafana Monitoring | Observability | Keycloak + `it-admin` role |
| `mgmt.charif-labs.tech` | Portainer CE | Foundation | Keycloak + `it-admin` role |
| *(localhost:8200)* | Vault UI | Secrets | Localhost only (not exposed via tunnel) |

---

## 🔐 Security Model

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Edge** | Cloudflare Zero Trust Tunnel | No open inbound ports on the host |
| **Identity** | Keycloak OIDC | Centralized SSO & RBAC |
| **Access** | Cloudflare Access Applications | Per-app policies (role-based) |
| **Network** | Docker Bridge (`sovereign_net`) | Container isolation |
| **Secrets** | HashiCorp Vault | Centralized secrets management (localhost-bound) |
| **Observability** | Wazuh + Prometheus/Grafana | Threat detection + infrastructure monitoring |
| **Host** | Ansible playbooks | Baseline hardening of the Docker host |

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

6. **[06 — Ansible Docker-Host Management](docs/06-Ansible-Docker-Host-Management.md)**  
   Inventory setup and playbooks for Linux Docker host baseline hardening.

7. **[07 — Zero Trust Access Configuration](docs/07-Zero-Trust-Access-Configuration.md)**  
   How Access Policies work, troubleshooting loops, and break-glass access.

8. **[08 — GitHub Actions CI/CD](docs/08-GitHub-Actions-CI-CD.md)**  
   Pipeline stages: secret scanning, validation, auto-tagging, and Portainer webhooks.

9. **[09 — Maintenance and Troubleshooting](docs/09-Maintenance-and-Troubleshooting.md)**  
   Common issues, log locations, restart procedures, and break-glass steps.

---

## ⚠️ Important Notes

- **Never commit secrets.** `.gitignore` already excludes `.env`, `*.tfvars`, and `terraform.tfstate`.
- **Keycloak is in `start-dev` mode.** For production, switch to `start` with proper hostname settings and a reverse-proxy certificate.
- **Wazuh default passwords** are hard-coded in `docker/2-applications/security/docker-compose.yml`. Rotate them before production use.
- **Cloudflare tunnel token** is base64-encoded JSON. Treat it as sensitive as an API key.
- **The `moved.tf` file** handles Terraform state migration from Cloudflare provider v4 to v5. Do not delete it if you have existing state.
- **Vault is bound to localhost only.** It is intentionally not exposed through the Cloudflare tunnel. Access it via `ssh -L 8200:localhost:8200 <host>`.
- **Ansible targets the Docker host.** All playbooks are designed for the Linux server running Docker, not for remote Windows endpoints.

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

# Restart individual application stack
docker compose -f docker/2-applications/security/docker-compose.yml restart
```

---

## 📜 License

This infrastructure template is provided as-is for educational and self-hosted security operations.  
Review and harden all default credentials before deploying to a production environment.

---

*Built with Terraform, Docker, Keycloak, Wazuh, Cloudflare Zero Trust, HashiCorp Vault, n8n, Prometheus/Grafana, and Ansible.*
