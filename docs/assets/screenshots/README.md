# Screenshot Assets

This directory holds all screenshots referenced by the project documentation.

## Naming Convention

Use the format: `{NN}-{short-description}.png`

| Prefix | Topic |
|--------|-------|
| `01-` | Prerequisites & Architecture |
| `02-` | Terraform Cloudflare Setup |
| `03-` | Docker Sovereign Stack |
| `04-` | Keycloak Identity Provider |
| `05-` | Wazuh XDR Deployment |
| `06-` | Ansible Docker-Host Management |
| `07-` | Zero Trust Access Configuration |
| `08-` | GitHub Actions CI/CD |
| `09-` | Maintenance & Troubleshooting |

## How to Replace Placeholders

1. Follow the step in the relevant guide.
2. Take a screenshot of the result.
3. Save it here with the matching filename from the doc.
4. The docs already reference these paths; no markdown edits needed.

> ⚠️ **Never commit screenshots that contain secrets, tokens, or passwords.** Blur or crop sensitive fields before saving.
