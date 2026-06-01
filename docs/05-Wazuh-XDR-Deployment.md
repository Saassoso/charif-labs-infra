# 05 — Wazuh XDR Deployment

> This phase details the deployment and initial configuration of the Wazuh XDR platform within your Docker environment, focusing on SSL certificates and basic access.

---

## 5.1 Understand the Wazuh Stack

The `docker/2-applications/security/docker-compose.yml` file defines three core Wazuh components:

-   **Wazuh Manager**: The central server that collects, analyzes, and correlates alerts from agents.
-   **Wazuh Indexer**: An OpenSearch instance (fork of Elasticsearch) for storing and indexing security events.
-   **Wazuh Dashboard**: A user interface (based on OpenSearch Dashboards) for visualizing and managing security data.

Key details:
-   All components are configured with TLS/SSL for secure communication.
-   Default passwords for the indexer and dashboard are hard-coded in the `docker-compose.yml` (e.g., `SecretPassword`). **Change these in production!**
-   Wazuh agents (deployed via Action1) will connect to the manager via ports `1514` (agent data) and `1515` (agent enrollment).

---

## 5.2 Initial Access to Wazuh Dashboard

After the Docker stack has been launched (refer to [Phase 3](03-Docker-Sovereign-Stack.md)), the Wazuh services should be starting up.

1.  Browse to the Wazuh Dashboard: `https://wazuh.charif-labs.tech`
2.  You will be prompted for credentials. Use the default `admin` username and `SecretPassword` for the password (unless you changed it).

> ⚠️ **Patience is key:** The Wazuh Indexer and Dashboard can take several minutes to fully initialize on the first boot as they create necessary indices and set up internal configurations. You might see a "Wazuh dashboard server is not ready yet" message. Wait a few minutes and refresh.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/05-wazuh-dashboard-login.png`
> **Description:** Wazuh Dashboard login screen.

---

## 5.3 Change Default Passwords (Critical for Production)

The `docker/2-applications/security/docker-compose.yml` file contains hard-coded passwords for the Wazuh Indexer and Dashboard. **You MUST change these immediately for any production deployment.**

1.  Edit `docker/2-applications/security/docker-compose.yml`.
2.  Locate `INDEXER_PASSWORD` in `wazuh.manager` and `wazuh.indexer` services.
3.  Locate `DASHBOARD_PASSWORD` in `wazuh.dashboard` service.
4.  Locate `API_PASSWORD` in `wazuh.manager` and `wazuh.dashboard` services.
5.  Replace `SecretPassword` and `MyS3cr37P450r.*-` with strong, unique passwords.
6.  Update the `internal_users.yml` file (`docker/2-applications/security/config/wazuh_indexer/internal_users.yml`) to reflect the new Indexer `admin` password. You will need to hash the password using the `securityadmin.sh` script inside the `wazuh.indexer` container. See [Wazuh documentation](https://documentation.wazuh.com/current/user-manual/configuring-cluster/indexer-certs-tool.html#password-management) for details.
7.  Restart the Wazuh stack to apply changes:
    ```bash
    cd docker/2-applications/security
    sudo docker compose restart
    ```

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/05-wazuh-compose-passwords.png`
> **Description:** Snippet of `docker/2-applications/security/docker-compose.yml` with password fields highlighted for modification.

---

## 5.4 SSL Certificates for Wazuh Components

The Wazuh stack is configured to use SSL/TLS for all internal communication and external dashboard access. The certificates are mounted from the `docker/2-applications/security/config/wazuh_indexer_ssl_certs/` directory.

These certificates are generated as part of the initial setup. If you need to regenerate them, consult the official Wazuh documentation for the `wazuh-certs-tool.sh` utility.

| File | Purpose |
|------|---------|
| `root-ca.pem` | Root CA for all components |
| `wazuh.manager.pem`, `wazuh.manager-key.pem` | Manager's certificate and key |
| `wazuh.indexer.pem`, `wazuh.indexer-key.pem` | Indexer's certificate and key |
| `wazuh.dashboard.pem`, `wazuh.dashboard-key.pem` | Dashboard's certificate and key |
| `admin.pem`, `admin-key.pem` | Admin certificate for Indexer security configuration |

---

## 5.5 Wazuh Agent Enrollment and Configuration (Action1)

**Wazuh agents are deployed, enrolled, and configured on endpoints using Action1, not Ansible.**

Action1 provides a centralized management platform for endpoint deployment. The process typically involves:

1.  **Downloading the Agent Installer**: From the Wazuh Dashboard, generate the agent installation command for your specific OS (e.g., Windows, Linux).
2.  **Creating a Deployment Package in Action1**: Package the Wazuh agent installer and any required configuration files (e.g., `ossec.conf` with the manager IP and agent name) within Action1.
3.  **Configuring Enrollment**: Action1 scripts can automate the enrollment process, including registering the agent with the Wazuh Manager (using `manage_agents -i <manager_ip>` or the `authd` service over port `1515`).
4.  **Deploying Custom Configuration**: Deploy a customized `ossec.conf` to agents that includes specific FIM (File Integrity Monitoring) paths, log collection rules, or Sysmon integration settings.

**Key considerations for Action1 deployment:**

-   **Manager IP/Hostname**: Agents need to know how to reach the Wazuh Manager. Since we are using Cloudflare Tunnels, agents will connect to `wazuh-agent.charif-labs.tech` (for agent data `1514`) and `wazuh-auth.charif-labs.tech` (for registration `1515`). Ensure these DNS records are correctly resolving to your tunnel.
-   **Agent Groups**: Organize agents into groups within Wazuh for easier policy management (e.g., `windows-servers`, `linux-workstations`). Action1 deployment scripts can assign agents to these groups during installation.
-   **Sysmon Integration (Windows)**: For Windows endpoints, Action1 can be used to deploy Sysmon and configure it to send events to the Wazuh agent, enriching telemetry.

Consult the Action1 documentation and Wazuh agent deployment guides for detailed, platform-specific instructions on integrating the two platforms.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/05-wazuh-agents-overview.png`
> **Description:** Wazuh Dashboard → Agents section, showing a list of enrolled agents and their status.

---

## 5.6 Wazuh Manager Configuration (`ossec.conf`)

The main configuration for the Wazuh Manager is provided via a mounted volume: `./config/wazuh_cluster/wazuh_manager.conf` to `/wazuh-config-mount/etc/ossec.conf`.

This file controls core manager behavior, including:
-   Agent connection settings
-   Rules and decoders directories
-   Alerts and logs output settings
-   Integrations (e.g., VirusTotal, PagerDuty)

Review this file to understand the manager's default behavior and customize it as needed for your environment.

---

**Next Step:** [06 — Ansible Docker-Host Management](06-Ansible-Docker-Host-Management.md)
