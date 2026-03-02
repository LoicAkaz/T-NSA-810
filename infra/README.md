# Infrastructure (Terraform)

## Purpose

Ce répertoire contient le code Terraform responsable du provisionnement:

- Machines Virtuelles (Proxmox)
- Réseaux
- Configuration VPN
- Règles du pare-feu (si nécessaire)

---

## Structure

- `environments/` → Déploiements spécifiques au site
  - `local/`
  - `onprem/`
- `modules/` → Modules Terraform Réutilisable
  - `vm/`
  - `network/`
  - `vpn/`
- `providers.tf` → Configuration du fournisseur
- `variables.tf` → variables Globales

---

## Usage

Initialiser Terraform:

```bash
terraform init