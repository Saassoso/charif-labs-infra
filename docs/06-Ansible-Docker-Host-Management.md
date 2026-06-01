# 06 — Ansible Docker-Host Management

> This phase covers using Ansible to manage and harden the Linux Docker host where all services are running. It focuses on initial setup and example playbooks for baseline configuration.

---

## 6.1 Understanding Ansible's Role

In this project, Ansible's primary role is **configuration management for the Linux Docker host itself**, not for deploying agents to remote endpoints (which is handled by Action1).

Ansible playbooks can be used for:
-   Installing prerequisite packages (e.g., `ntp`, `git`, `htop`)
-   Configuring system services (e.g., NTP synchronization)
-   Applying security baselines (e.g., SSH hardening, firewall rules)
-   Automating routine maintenance tasks

---

## 6.2 Ansible Inventory

The `ansible/inventory.ini` file defines the hosts that Ansible will manage. For this project, it will typically point to your Docker host.

### Example `ansible/inventory.ini`

```ini
[docker_hosts]
your_docker_host_ip_or_hostname ansible_user=your_ssh_username ansible_ssh_private_key_file=/path/to/your/ssh/key

[all:vars]
ansible_python_interpreter=/usr/bin/python3
```

-   Replace `your_docker_host_ip_or_hostname` with the IP address or hostname of your Linux Docker server.
-   Replace `your_ssh_username` with the SSH user you use to connect to the host.
-   Replace `/path/to/your/ssh/key` with the absolute path to your SSH private key. Alternatively, you can rely on `ssh-agent` if your key is already loaded.

**Connectivity Test:**

From your control machine (where Ansible is installed), test connectivity:

```bash
cd ansible/
ansible all -m ping -i inventory.ini
```

Expected successful output:

```
your_docker_host_ip_or_hostname | SUCCESS => {
    "ansible_facts": {
        "discovered_interpreter_python": "/usr/bin/python3"
    },
    "changed": false,
    "ping": "pong"
}
```

If you get errors, troubleshoot your SSH connection or inventory file first.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/06-ansible-ping.png`
> **Description:** Terminal showing successful `ansible all -m ping` output.

---

## 6.3 Example Playbooks

The `ansible/exemple/` directory contains sample playbooks to get you started.

### Example 1: `NTP_Installed.yaml` (Install NTP)

This playbook ensures the Network Time Protocol (NTP) package is installed and up-to-date on your Docker host. Accurate time synchronization is crucial for logging, security events, and certificate validation.

```yaml
# ansible/exemple/NTP_Installed.yaml
- name: Install the latest version of NTP
  hosts: docker_hosts
  become: true # Run with sudo/root privileges
  tasks:
    - name: Ensure NTP is installed
      ansible.builtin.apt:
        name: ntp
        state: latest
```

**Run this playbook:**

```bash
cd ansible/
ansible-playbook -i inventory.ini exemple/NTP_Installed.yaml
```

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/06-ansible-ntp-install.png`
> **Description:** Terminal showing successful `ansible-playbook` run for `NTP_Installed.yaml`.

### Example 2: `1.yaml` (System Information)

This simple playbook gathers and displays basic system information about the managed host.

```yaml
# ansible/exemple/1.yaml
--- 
- name : "A simple playbook"
  hosts : all
  tasks :
    - name : "Output some information on our host"
      ansible.builtin.debug :
        msg : "I am connecting to {{ ansible_nodename}} wich is running {{ ansible_distribution }} {{ ansible_distribution_version }}"
```

**Run this playbook:**

```bash
cd ansible/
ansible-playbook -i inventory.ini exemple/1.yaml
```

---

## 6.4 Extending Ansible for Host Hardening

You can extend the Ansible configurations to implement a robust security baseline for your Docker host. Consider playbooks for:

-   **SSH Hardening**: Disabling password authentication, enforcing key-based login, disabling root login, changing SSH port.
-   **Firewall Configuration**: Using `ufw` or `firewalld` to restrict inbound connections (though Cloudflare Tunnel handles external exposure).
-   **User Management**: Creating/managing administrative users with `sudo` access.
-   **Package Management**: Ensuring all system packages are up-to-date.
-   **Log Rotation**: Configuring `logrotate` for system and application logs.
-   **SELinux/AppArmor**: Implementing mandatory access control policies.

Remember to test playbooks in a development environment before applying them to your production Docker host.

---

**Next Step:** [07 — Zero Trust Access Configuration](07-Zero-Trust-Access-Configuration.md)
