# 08 — GitHub Actions CI/CD

> This phase describes the GitHub Actions workflow (`.github/workflows/pipeline.yml`) that automates security checks, validation, version tagging, and deployment triggers for the entire infrastructure.

---

## 8.1 Overview of the CI/CD Pipeline

The `pipeline.yml` workflow is triggered on `push` and `pull_request` events to the `main` branch. It consists of several sequential stages:

1.  **Security & Secrets Scanning**: Identifies hardcoded secrets and infrastructure-as-code vulnerabilities.
2.  **Validation & Linting**: Checks Terraform and Docker Compose configurations for syntax errors and best practices.
3.  **Automatic Version Tagging**: Bumps the project version (e.g., `v1.0.0`, `v1.0.1`) and creates a Git tag on successful pushes to `main`.
4.  **Portainer Deployment Trigger**: Calls Portainer webhooks to trigger updates for all Docker application stacks.

```yaml
# .github/workflows/pipeline.yml
name: Charif Labs Infrastructure CI/CD

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  security-checks: { ... }
  validate-infra: { ... }
  version-tagging: { ... }
  deploy-production: { ... }
```

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/08-github-actions-overview.png`
> **Description:** GitHub Actions workflow run summary showing all stages and their status.

---

## 8.2 Stage 1: Security & Secrets Scanning

This stage uses `Gitleaks` and `Trivy` to identify potential security issues early in the development cycle.

### Gitleaks (Hardcoded Secrets)

-   **Purpose**: Scans the Git history and current code for hardcoded credentials, API keys, and other sensitive information.
-   **Action**: `gitleaks/gitleaks-action@v2`
-   **Configuration**: Requires `GITHUB_TOKEN` and `GITLEAKS_LICENSE` secrets.

```yaml
# .github/workflows/pipeline.yml (excerpt)
  security-checks:
    name: Security & Secrets Scan
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0 # Required for full history scan

      - name: Scan for Hardcoded Secrets (Gitleaks)
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}
```

### Trivy (IaC Vulnerability Scan)

-   **Purpose**: Scans Infrastructure as Code (Terraform, Docker Compose, Ansible) files for misconfigurations and known vulnerabilities.
-   **Action**: `aquasecurity/trivy-action@master`
-   **Configuration**: `scan-type: 'config'`, `severity: 'CRITICAL,HIGH'`, `exit-code: '1'` (fails the pipeline).

```yaml
# .github/workflows/pipeline.yml (excerpt)
      - name: Infrastructure as Code Vulnerability Scan (Trivy)
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'config' # Scans Terraform, Docker, and Ansible files
          hide-progress: false
          format: 'table'
          exit-code: '1' # Fails the pipeline if critical vulnerabilities are found
          severity: 'CRITICAL,HIGH'
```

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/08-trivy-scan-output.png`
> **Description:** GitHub Actions run log showing Trivy scan output (table format) with detected vulnerabilities.

---

## 8.3 Stage 2: Validation & Linting

This stage ensures that Terraform and Docker Compose files are syntactically correct and follow formatting standards.

### Terraform Format & Validate

-   **Purpose**: Checks `terraform/` files for proper formatting (`terraform fmt -check`) and validates the configuration (`terraform validate`).
-   **Action**: `hashicorp/setup-terraform@v3` is used to set up the Terraform CLI.

```yaml
# .github/workflows/pipeline.yml (excerpt)
  validate-infra:
    name: Validate Terraform, Docker & Ansible
    runs-on: ubuntu-latest
    needs: security-checks
    steps:
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v3

      - name: Terraform Format Check
        run: terraform fmt -check
        working-directory: ./terraform

      - name: Terraform Validate
        run: |
          terraform init -backend=false # -backend=false prevents state backend config errors
          terraform validate
        working-directory: ./terraform
```

### Docker Compose Validation

-   **Purpose**: Validates the syntax of `docker/docker-compose.yml` and all included files.
-   **Command**: `docker compose config -q` (the `-q` flag suppresses output and only returns exit code).

```yaml
# .github/workflows/pipeline.yml (excerpt)
      - name: Validate Docker Compose
        run: |
          # Create a dummy .env so Compose doesn't fail on missing variables
          touch docker/.env
          docker compose -f docker/docker-compose.yml config -q
```

> **Note**: A dummy `.env` is created to prevent `docker compose config` from failing if environment variables are expected but not present in the CI/CD environment.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/08-terraform-validate.png`
> **Description:** GitHub Actions run log showing successful Terraform validation steps.

---

## 8.4 Stage 3: Automatic Version Tagging

This stage automatically bumps the project version and creates a Git tag after a successful push to `main`.

-   **Purpose**: Automates versioning (e.g., `v1.0.0`, `v1.0.1`) based on commit history.
-   **Action**: `mathieudutour/github-tag-action@v6.2`
-   **Configuration**: `default_bump: minor`, `release_branches: main`, and requires `contents: write` permission.

```yaml
# .github/workflows/pipeline.yml (excerpt)
  version-tagging:
      name: Auto-Tag Version
      runs-on: ubuntu-latest
      needs: validate-infra
      if: github.event_name == 'push' && github.ref == 'refs/heads/main'
      
      permissions:
        contents: write # Important: required to push tags
      
      outputs:
        new_tag: ${{ steps.tag_version.outputs.new_tag }}
      steps:
        - name: Checkout Code
          uses: actions/checkout@v4

        - name: Bump version and push tag
          id: tag_version
          uses: mathieudutour/github-tag-action@v6.2
          with:
            github_token: ${{ secrets.GITHUB_TOKEN }}
            default_bump: minor 
            release_branches: main
```

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/08-version-tagging-success.png`
> **Description:** GitHub Actions run log showing the successful creation of a new version tag.

---

## 8.5 Stage 4: Portainer Deployment Trigger

This final stage triggers the deployment of updated Docker stacks by calling Portainer webhooks.

-   **Purpose**: Notifies Portainer that a new version of the code has been pushed, prompting it to pull new images and restart services.
-   **Command**: `curl -X POST "${{ secrets.PORTAINER_WEBHOOK_... }}"` for each application stack.
-   **Configuration**: Requires several GitHub Secrets (e.g., `PORTAINER_WEBHOOK_AUTOMATION`, `PORTAINER_WEBHOOK_IDENTITY`) which store the unique webhook URLs for each stack in Portainer.

```yaml
# .github/workflows/pipeline.yml (excerpt)
  deploy-production:
    name: Trigger Portainer Webhook
    runs-on: ubuntu-latest
    needs: version-tagging
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - name: Call Portainer Webhooks
        run: |
          curl -X POST "${{ secrets.PORTAINER_WEBHOOK_AUTOMATION }}"
          curl -X POST "${{ secrets.PORTAINER_WEBHOOK_IDENTITY }}"
          curl -X POST "${{ secrets.PORTAINER_WEBHOOK_OBSERVABILITY }}"
          curl -X POST "${{ secrets.PORTAINER_WEBHOOK_SECRETS }}"
          curl -X POST "${{ secrets.PORTAINER_WEBHOOK_SECURITY }}"
```

### Setting up Portainer Webhooks

1.  **In Portainer**: Navigate to a specific stack (e.g., `automation_stack`).
2.  Click `Webhooks` (or equivalent section for GitOps deployments).
3.  Generate a new custom webhook URL. This URL is unique to the stack and contains a secret token.
4.  **In GitHub**: Go to your repository `Settings` → `Secrets and variables` → `Actions`.
5.  Create new repository secrets (e.g., `PORTAINER_WEBHOOK_AUTOMATION`) and paste the generated Portainer webhook URL as the value.

<!-- SCREENSHOT_PLACEHOLDER -->
> 🖼️ **Screenshot Placeholder**
> **File:** `docs/assets/screenshots/08-portainer-webhook-setup.png`
> **Description:** Portainer UI showing the webhook URL generation for a specific stack.

---

**Next Step:** [09 — Maintenance and Troubleshooting](09-Maintenance-and-Troubleshooting.md)
