# CIA - Deployment and Securing of a Hybrid Infrastructure

## Project Description

This project designs, deploys, and secures a hybrid infrastructure across two Proxmox VE sites (one local and one remote).
The goal is to build an evolutive, highly available, and automated platform using a GitOps approach with `ansible-pull` and the Elastic Stack for observability.

## Main Objectives

- Hybrid architecture with two interconnected Proxmox sites
- Secure site-to-site VPN and pfSense firewalls with kill switch capability
- Controlled external access through a bastion host
- Automated IPAM with NetBox
- Centralized observability with the Elastic Stack
- Strong traffic segmentation (Admin / Users / Services) and least privilege

## Technical Stack

| Component | Technology | Description |
| :--- | :--- | :--- |
| Virtualization | Proxmox VE | Bare-metal virtualization platform |
| Firewall / Routing | pfSense | Network filtering and reduced exposure |
| VPN | OpenVPN | Encrypted site-to-site interconnection |
| Configuration | Ansible (Pull) | Continuous configuration management from Git |
| IPAM | NetBox | Source of truth for network addressing |
| Observability | Elastic Stack | Log collection, analysis, and monitoring |

## Repository Structure

- `infra/`: Terraform infrastructure code
- `ansible/`: Playbooks and roles for configuration management
- `README.md`: Project overview

## CI Overview

The GitHub Actions pipeline validates infrastructure code before merge:

- Terraform setup (`hashicorp/setup-terraform@v3`)
- `terraform fmt -check -recursive`
- `terraform init -backend=false`
- `terraform validate`
- `tflint --recursive`
- `tfsec` security scan
- Ansible lint checks (`yamllint`, `ansible-lint`)

## Notes

- Terraform CLI version is pinned in CI and must stay consistent with `infra/modules/terraform.tf`.
- The Terraform module must define `required_version` to satisfy TFLint (`terraform_required_version`).

---
Project developed as part of the EPITECH curriculum.
