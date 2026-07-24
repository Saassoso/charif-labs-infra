# Sovereign Security Stack v2.0 — CHARif-LABS-INFRA

> A self-hosted, Zero-Trust Security Operations (SecOps) platform designed for comprehensive threat detection, identity management, and automated security workflows. Built on a robust stack of Docker, Terraform, and Ansible, all services are securely exposed via Cloudflare Zero Trust Tunnels with Keycloak OIDC authentication.

---

## 📖 Table of Contents
- [🌟 Introduction](#-introduction)
- [✨ Features](#-features)
- [🏗️ Architecture Overview](#️-architecture-overview)
- [🛠️ Technologies Used](#️-technologies-used)
- [📁 Repository Structure](#-repository-structure)
- [🚀 Getting Started](#-getting-started)
  - [Prerequisites](#prerequisites)
  - [Phase 1 — Terraform (Cloudflare IaC)](#phase-1--terraform-cloudflare-iac)
  - [Phase 2 — Docker Sovereign Stack](#phase-2--docker-sovereign-stack)
  - [Phase 3 — Keycloak Configuration](#phase-3--keycloak-configuration)
  - [Phase 4 — Wazuh XDR Deployment](#phase-4--wazuh-xdr-deployment)
  - [Phase 5 — Ansible Docker-Host Management](#phase-5--ansible-docker-host-management)
  - [Phase 6 — Verify Zero Trust Access](#phase-6--verify-zero-trust-access)
- [🌐 Service Map](#-service-map)
- [🔐 Security Model](#-security-model)
- [📖 Documentation](#-documentation)
- [⚠️ Important Notes](#️-important-notes)
- [🛠️ Maintenance & Troubleshooting](#️-maintenance--troubleshooting)
- [🤝 Contributing](#-contributing)
- [📜 License](#-license)
- [📧 Contact](#-contact)

---

## 🎯 Project Goals and Objectives

This project aims to establish a robust, secure, and automated infrastructure for security operations, focusing on the following key objectives:

-   **Implement Zero-Trust Security:** Eliminate implicit trust by verifying every access request, regardless of origin, through Cloudflare Zero Trust.
-   **Automate Infrastructure Deployment (IaC):** Manage Cloudflare resources and host configurations using Terraform and Ansible to ensure consistency, repeatability, and version control.
-   **Centralize Identity and Access Management (IAM):** Provide a single, secure identity provider (Keycloak) for all services, enforcing OIDC-based authentication.
-   **Enhance Threat Detection and Response (XDR):** Deploy a comprehensive security monitoring solution (Wazuh) for endpoint protection, log analysis, and incident detection.
-   **Streamline Operations with Containerization:** Utilize Docker and Docker Compose for efficient, scalable, and isolated deployment of all application services.
-   **Integrate DevSecOps Practices:** Incorporate automated security scanning, validation, and continuous deployment through GitHub Actions to maintain a secure and agile development lifecycle.
-   **Ensure High Availability and Resiliency:** Design the stack to be resilient to component failures through container orchestration and modular service design (though explicit multi-node HA is beyond the scope of a single-host deployment, the architecture supports future scaling).

---

## 🌟 Introduction

This project, CHARif-LABS-INFRA, offers a comprehensive, self-hosted solution for modern security operations, enabling organizations to achieve a robust security posture through a Zero-Trust framework. It integrates cutting-edge open-source and community-edition tools to provide:

-   **Centralized Identity and Access Management (IAM):** Secure authentication and authorization with Keycloak.
-   **Extended Detection and Response (XDR):** Comprehensive security monitoring and threat detection with Wazuh.
-   **Infrastructure as Code (IaC):** Automated provisioning and management of Cloudflare resources with Terraform.
-   **Container Orchestration:** Efficient deployment and scaling of services using Docker and Docker Compose.
-   **Configuration Management:** Baseline hardening and maintenance of Docker hosts with Ansible.
-   **Observability:** Integrated monitoring and alerting with Prometheus and Grafana.
-   **Secrets Management:** Secure storage and access to sensitive information with HashiCorp Vault.
-   **Workflow Automation:** Streamlined security and operational tasks with n8n.

This stack is optimized for deployment on a single Linux Docker host, fortified against internet threats by Cloudflare Zero Trust Tunnels. This architecture inherently eliminates the necessity for traditional inbound firewall rules, shifting protection to the edge.

---

## ✨ Features

-   **Zero Trust Architecture:** All external access secured via Cloudflare Zero Trust Tunnels, eliminating public inbound ports.
-   **Identity-Centric Security:** Keycloak as the central Identity Provider (IdP) for all applications, enforcing OIDC-based authentication.
-   **Comprehensive XDR:** Wazuh for endpoint security, log analysis, intrusion detection, and compliance monitoring.
-   **Automated Infrastructure:** Terraform manages Cloudflare DNS, Tunnels, Access Policies, and Email Routing.
-   **Modular Containerized Services:** Docker Compose orchestrates independent application stacks (Identity, Security, Observability, Automation, Secrets).
-   **Secure Secrets Management:** HashiCorp Vault provides centralized, audited storage for sensitive data (localhost-bound).
-   **Proactive Monitoring:** Prometheus and Grafana for real-time insights into system and application health.
-   **Workflow Automation:** n8n for building automated workflows, integrating various services and responding to events.
-   **DevSecOps Automation:** GitHub Actions provide a robust CI/CD pipeline, integrating automated security scanning, validation, version tagging, and Portainer-triggered deployments to ensure secure and efficient operations. This embodies the DevSecOps principle of shifting security left, integrating it throughout the development and deployment lifecycle.
-   **Host Hardening:** Ansible playbooks are utilized for establishing a secure baseline configuration and continuous management of the Docker host, including essential security controls.

---

## 🏗️ Architecture Overview
The platform's architecture is meticulously designed with a layered security approach, where Cloudflare Zero Trust serves as the primary secure edge, safeguarding all internally hosted services. This setup inherently negates the need for traditional firewall configurations by ensuring all traffic is brokered through Cloudflare's secure network.

The platform's architecture is built on a layered approach, with Cloudflare Zero Trust acting as the secure edge, protecting all internally hosted services.

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

## 🛠️ Key Technologies & Concepts
This project leverages a diverse array of technologies, orchestrating them to deliver a resilient, secure, and automated infrastructure. Below are the core components and concepts employed:

-   **Cloudflare Zero Trust:** Secure connectivity and access control.
-   **Terraform:** Infrastructure as Code for Cloudflare resources.
-   **Docker & Docker Compose:** Containerization and orchestration.
-   **Ansible:** For configuration management, host hardening, and automated deployment tasks on the Docker host, ensuring consistency and security.
-   **Keycloak:** Open-source Identity and Access Management (IAM) and SSO.
-   **Wazuh:** XDR platform for security monitoring, log analysis, and threat detection.
-   **HashiCorp Vault:** Secrets management.
-   **n8n:** Workflow automation tool.
-   **Prometheus:** Monitoring system.
-   **Grafana:** Data visualization and dashboarding.
-   **PostgreSQL:** Database for Keycloak.
-   **CI/CD Pipeline:** Implemented via GitHub Actions, the pipeline integrates automated security scanning (e.g., for secrets), infrastructure validation (Terraform plan/apply dry runs), automatic version tagging, and webhook-triggered deployments to Portainer. This ensures that changes are validated and deployed consistently, minimizing manual errors and enhancing overall operational security and efficiency.

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

## 🚀 Getting Started

This section outlines the high-level deployment steps for the Sovereign Security Stack. **For detailed, copy-paste instructions and in-depth explanations, always refer to the specific guides located in the `docs/` directory.** Each phase below corresponds to a detailed document.

### Prerequisites
Before embarking on the deployment, ensure you have the following prerequisites in place:
-   **Cloudflare Account:** A domain registered and managed by Cloudflare is essential for leveraging its Zero Trust capabilities and DNS management.
-   **Linux Host:** A dedicated Linux server (e.g., Ubuntu LTS) with Docker and Docker Compose installed.
    -   **Minimum Specs:** 4 CPU cores, 8 GB RAM, 50 GB SSD.
    -   **Network:** The host only requires outbound HTTPS (443) access. Critically, **no inbound ports are required or should be opened on your firewall**, as all external access is mediated by Cloudflare Zero Trust Tunnels.
-   **Terraform CLI:** Version 1.5.0 or newer for managing Cloudflare infrastructure as code.
-   **Ansible:** For streamlined Docker host hardening and ongoing maintenance.
-   **Gmail Address:** Required for Cloudflare Email Routing's catch-all functionality.
-   **SSH Access:** To your Linux Docker host for initial setup and Ansible operations.

For a comprehensive guide on prerequisites and architectural considerations, refer to [01 — Prerequisites & Architecture](docs/01-Prerequisites-and-Architecture.md).

Before you begin, ensure you have the following:

-   **Cloudflare Account:** A domain registered and managed by Cloudflare.
-   **Linux Host:** A dedicated Linux server (e.g., Ubuntu LTS) with Docker and Docker Compose installed.
    -   **Minimum Specs:** 4 CPU cores, 8 GB RAM, 50 GB SSD.
    -   **Network:** Outbound HTTPS (443) access only (no inbound ports required).
-   **Terraform CLI:** Version 1.5.0 or newer.
-   **Ansible:** For Docker host hardening and maintenance.
-   **Gmail Address:** For Cloudflare Email Routing catch-all.
-   **SSH Access:** To your Linux Docker host.

### Phase 1 — Terraform (Cloudflare IaC)

1.  **Navigate to `terraform/`:**
    ```bash
    cd terraform/
    ```
2.  **Create `terraform.tfvars`:**
    ```hcl
    cloudflare_account_id = "your_account_id"
    cloudflare_zone_id    = "your_zone_id"
    cloudflare_api_token  = "your_api_token"
    keycloak_client_secret = "placeholder-will-update-later" # Update later in Phase 5
    forwarding_email       = "your-gmail@gmail.com"
    admin_email            = "your-admin-email@gmail.com"
    ms_verification_code   = "MS=msxxxxxxx" # Optional: For Microsoft domain verification
    google_site_verification_code = "google-site-verification=..." # Optional: For Google domain verification
    ```
    *Replace placeholders with your actual Cloudflare credentials and email addresses. Refer to [02 — Terraform Cloudflare Setup](docs/02-Terraform-Cloudflare-Setup.md) for detailed instructions.*
3.  **Initialize & Apply:**
    ```bash
    terraform init
    terraform plan
    terraform apply
    ```
    This step provisions all necessary Cloudflare resources: Zero Trust Tunnels, DNS records, Email routing, and initial Access Applications. It effectively configures your edge firewall via Cloudflare. **Crucially, copy the sensitive `cloudflare_zero_trust_tunnel_cloudflared_token` output; it will be needed in the next phase.**

### Phase 2 — Docker Sovereign Stack

1.  **Create Shared Network:**
    ```bash
    cd docker/
    docker network create sovereign_net
    ```
2.  **Configure Application Secrets:** Create `.env` files for Keycloak passwords and optionally for n8n basic auth and Cloudflared tunnel token.
    ```bash
    # For Keycloak (REQUIRED):
    cat > docker/2-applications/identity/.env << 'EOF'
    KC_DB_PASSWORD=<strong_random_password>
    KC_ADMIN_PASSWORD=<strong_random_password>
    EOF

    # For Cloudflared (REQUIRED, paste token from Phase 1 output):
    cat > docker/1-foundation/cloudflared/.env << 'EOF'
    TUNNEL_TOKEN="paste-your-base64-token-here"
    EOF
    ```
    *Refer to [03 — Docker Sovereign Stack](docs/03-Docker-Sovereign-Stack.md) for full details.*
3.  **Launch Docker Stack:**
    ```bash
    sudo docker compose --env-file ./2-applications/identity/.env \
                         --env-file ./1-foundation/cloudflared/.env \
                         up -d
    ```
    This command launches all containerized services, including Cloudflared, Keycloak, PostgreSQL, Portainer, Vault, n8n, Wazuh, Prometheus, and Grafana. The Docker Compose setup inherently provides a level of high availability and service orchestration for the application stack.

### Phase 3 — Keycloak Configuration

1.  **Access Admin Console:** Log in to `https://keycloak-admin.your-domain.com` using `admin` and `KC_ADMIN_PASSWORD`.
2.  **Create Realm:** Create a new realm named `charif-labs`.
3.  **Configure OIDC Client:** Create a client named `cloudflare-access` with appropriate redirect URIs and web origins.
4.  **Retrieve Client Secret:** Copy the generated `Client Secret` from Keycloak.
5.  **Update Terraform:** Paste the `Client Secret` into `terraform/terraform.tfvars` and re-run `terraform apply`.
6.  **User Attributes & Mappers:** Create a `ztna_role` user attribute and an OIDC mapper to include it in tokens.
7.  **Create Users & Groups:** Create an `it-admin` group and an admin user, assigning them to the group and setting `ztna_role`.

*For comprehensive details on Keycloak configuration, including realm setup, OIDC client specifics, user attributes, and IdP mapping, refer to [04 — Keycloak Identity Provider](docs/04-Keycloak-Identity-Provider.md).*

### Phase 4 — Wazuh XDR Deployment

1.  **Access Dashboard:** Browse to `https://wazuh.your-domain.com` and log in with default credentials (`admin`/`SecretPassword`).
2.  **Change Default Passwords:** **CRITICAL!** Update `INDEXER_PASSWORD`, `DASHBOARD_PASSWORD`, and `API_PASSWORD` in `docker/2-applications/security/docker-compose.yml` and restart the Wazuh stack. Update `internal_users.yml` and hash the new password within the `wazuh.indexer` container.

*For detailed steps on Wazuh deployment, including SSL certificates, indexer configuration, dashboard access, and agent enrollment, refer to [05 — Wazuh XDR Deployment](docs/05-Wazuh-XDR-Deployment.md).*

### Phase 5 — Ansible Docker-Host Management

1.  **Configure `ansible/inventory.ini`:** Update with your Docker host's IP/hostname, SSH user, and private key path.
2.  **Test Connectivity:**
    ```bash
    cd ansible/
    ansible all -m ping -i inventory.ini
    ```
3.  **Run Example Playbooks:**
    ```bash
    ansible-playbook -i inventory.ini exemple/NTP_Installed.yaml
    ```
    Extend with additional playbooks for SSH hardening, firewall configuration, and other security baselines.

*For an in-depth guide on Ansible inventory setup, host hardening playbooks, and secure configuration management for your Linux Docker host, refer to [06 — Ansible Docker-Host Management](docs/06-Ansible-Docker-Host-Management.md).*

### Phase 6 — Verify Zero Trust Access

Browse to each service and confirm Cloudflare Access prompts for Keycloak login, and that you can successfully authenticate with your configured `it-admin` user:

-   `https://wazuh.your-domain.com`
-   `https://mgmt.your-domain.com` (Portainer)
-   `https://grafana.your-domain.com`
-   `https://n8n.your-domain.com`

*To understand how Cloudflare Access Policies function, troubleshoot authentication loops, and implement break-glass access, refer to [07 — Zero Trust Access Configuration](docs/07-Zero-Trust-Access-Configuration.md).*

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
|-------|------------|---------|\
| **Edge** | Cloudflare Zero Trust Tunnel | No open inbound ports on the host |
| **Identity** | Keycloak OIDC | Centralized SSO & RBAC |
| **Access** | Cloudflare Access Applications | Per-app policies (role-based) |
| **Network** | Docker Bridge (`sovereign_net`) | Container isolation |
| **Secrets** | HashiCorp Vault | Centralized secrets management (localhost-bound) |
| **Observability** | Wazuh + Prometheus/Grafana | Threat detection + infrastructure monitoring |
| **Host** | Ansible playbooks | Baseline hardening of the Docker host |

---

## 📖 Documentation

Each document provides a standalone, step-by-step guide. It is recommended to read them in the following order:

1.  **[01 — Prerequisites & Architecture](docs/01-Prerequisites-and-Architecture.md)**: Hardware, software, and Cloudflare account requirements.
2.  **[02 — Terraform Cloudflare Setup](docs/02-Terraform-Cloudflare-Setup.md)**: Authenticate, plan, and apply the entire Cloudflare layer.
3.  **[03 — Docker Sovereign Stack](docs/03-Docker-Sovereign-Stack.md)**: Install Docker, create the network, and launch all services.
4.  **[04 — Keycloak Identity Provider](docs/04-Keycloak-Identity-Provider.md)**: Realm creation, client setup, user attributes, and Cloudflare IdP mapping.
5.  **[05 — Wazuh XDR Deployment](docs/05-Wazuh-XDR-Deployment.md)**: SSL certificates, indexer configuration, dashboard access, and agent enrollment.
6.  **[06 — Ansible Docker-Host Management](docs/06-Ansible-Docker-Host-Management.md)**: Inventory setup and playbooks for Linux Docker host baseline hardening.
7.  **[07 — Zero Trust Access Configuration](docs/07-Zero-Trust-Access-Configuration.md)**: How Access Policies work, troubleshooting loops, and break-glass access.
8.  **[08 — GitHub Actions CI/CD](docs/08-GitHub-Actions-CI-CD.md)**: Pipeline stages: secret scanning, validation, auto-tagging, and Portainer webhooks.
9.  **[09 — Maintenance and Troubleshooting](docs/09-Maintenance-and-Troubleshooting.md)**: Common issues, log locations, restart procedures, and break-glass steps.

---

## ⚠️ Important Notes

-   **Never commit secrets.** `.gitignore` already excludes `.env`, `*.tfvars`, and `terraform.tfstate`.
-   **Keycloak is in `start-dev` mode.** For production, switch to `start` with proper hostname settings and a reverse-proxy certificate.
-   **Wazuh default passwords** are hard-coded in `docker/2-applications/security/docker-compose.yml`. **Rotate them immediately before production use.**
-   **Cloudflare tunnel token** is base64-encoded JSON. Treat it as sensitive as an API key.
-   **The `moved.tf` file** handles Terraform state migration from Cloudflare provider v4 to v5. Do not delete it if you have existing state.
-   **Vault is bound to localhost only.** It is intentionally not exposed through the Cloudflare tunnel. Access it via `ssh -L 8200:localhost:8200 <host>`.
-   **Ansible for Docker Host Management:** Ansible playbooks are specifically crafted for the Linux server hosting Docker, ensuring secure and consistent configuration of the infrastructure rather than application-level deployment.
-   **Wazuh Agent Deployment:** It's important to note that Wazuh agents for endpoint security are deployed and managed on target systems (e.g., Windows, Linux workstations) via Action1 or similar endpoint management solutions, not directly through Ansible within this project's scope.

---

## 🛠️ Maintenance & Troubleshooting

### General Docker Commands

-   **View all running containers:** `docker compose -f docker/docker-compose.yml ps`
-   **Restart the entire stack:** `docker compose -f docker/docker-compose.yml restart`
-   **View Cloudflared logs:** `docker logs cloudflared-tunnel --follow`
-   **Restart individual application stack:** `docker compose -f docker/2-applications/security/docker-compose.yml restart`
-   **Update all Docker images:**
    ```bash
    cd docker/
    sudo docker compose pull
    sudo docker compose up -d --remove-orphans
    ```

### Terraform Maintenance

-   **Re-apply Terraform after changing variables:** `terraform -chdir=terraform apply`
-   **Backup Terraform state:** `cp terraform.tfstate terraform.tfstate.backup.$(date +%s)`

### Common Issues

-   **Cloudflared: "Token not provided"**: Verify `TUNNEL_TOKEN` environment variable or `docker/1-foundation/cloudflared/.env`.
-   **Keycloak: Database not reachable**: If Keycloak PostgreSQL volume is corrupted, consider wiping `keycloak_database` volume (use with caution).
-   **Wazuh Dashboard: "Wazuh dashboard server is not ready yet"**: Wait a few minutes for services to initialize; check indexer logs if persistent.
-   **Authentication Loop**: Ensure `auth.your-domain.com` has a `bypass` policy in Cloudflare Access and Keycloak client redirect URIs are correct.
-   **403 Forbidden / Access Denied**: Check Keycloak user groups/roles and Cloudflare Zero Trust Audit Logs (`Zero Trust` → `Access` → `Audit Logs`).

*For more in-depth troubleshooting guides, common issue resolutions, log locations, restart procedures, and break-glass steps, refer to [09 — Maintenance and Troubleshooting](docs/09-Maintenance-and-Troubleshooting.md).*

---

## 🤝 Contributing

This project is primarily maintained for the CHARif-LABS-INFRA PFE (Projet de Fin d'Études). While direct contributions are not solicited for the immediate submission, the following general guidelines are provided for any future development, extensions, or community involvement:

1.  **Fork the Repository:** Start by forking this repository.
2.  **Create a New Branch:** For each feature or bug fix, create a new branch (e.g., `feature/new-service`, `bugfix/wazuh-password`).
3.  **Adhere to Best Practices:**
    -   Follow existing code styles for Terraform, Docker Compose, and Ansible.
    -   Ensure all changes are well-documented.
    -   Update `docs/` files relevant to your changes.
    -   Test your changes thoroughly.
4.  **Open Pull Requests:** Submit pull requests to the `main` branch with a clear description of your changes.

---

## 📜 License

This infrastructure template is provided as-is for educational and self-hosted security operations during the PFE. Review and harden all default credentials before deploying to a production environment.

---

## 📧 Contact

For any questions, issues, or inquiries regarding this project, please open an issue on the GitHub repository or contact the project maintainers:

-   **[Charif LABS Infrastructure Team]** - `contact@charif-labs.tech`

---

*Built with Terraform, Docker, Keycloak, Wazuh, Cloudflare Zero Trust, HashiCorp Vault, n8n, Prometheus/Grafana, and Ansible.*
