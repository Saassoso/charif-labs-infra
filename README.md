# CHARif-LABS-INFRA

```
charif-labs-infra/
├── 📂 terraform/              # Configuration du Control Plane (Phase 0)
│   ├── main.tf                # Définition du Tunnel ZTNA et DNS Records
│   ├── variables.tf           # Déclaration des variables (ex: domain_name)
│   ├── provider.tf            # Configuration provider Cloudflare
│   ├── ingress.tf             # Règles de routage Ingress (ZTNA)
│   └── .terraform.lock.hcl    # Verrouillage des versions des providers
├── 📂 docker/                 # Configuration de l'Execution Plane (Phase 1 & 3 & 4)
│   ├── 📂 core-identity/      # Les services d'identité
│   │   └── docker-compose.yml # Contient Authentik + Cloudflared (Aucun port exposé)
│   ├── 📂 xdr/                # Déploiement futur de Wazuh
│   └── 📂 soar/               # Déploiement futur de n8n
├── 📂 ansible/                # Configuration du Management Plane (Phase 2)
│   ├── inventory.ini          # Liste des endpoints Windows (VLAN 20)
│   ├── group_vars/            # Variables chiffrées (Ansible Vault pour WinRM)
│   └── playbooks/             # Scripts de durcissement et déploiement GCPW
├── .gitignore                 # CRITIQUE : Ignore .tfstate, .tfvars, crash.log
└── README.md                  # Instructions de déploiement Bootstrap
```