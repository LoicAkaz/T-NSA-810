# Infrastructure (Terraform)

## Purpose

This directory contains Terraform code used to provision:

- Virtual machines (Proxmox)
- Network resources
- VPN configuration
- Firewall rules (if required)

## Structure

- `environments/`: site-specific deployments (`local/`, `onprem/`)
- `modules/`: reusable Terraform modules (`vm/`, `network/`, `vpn/`)
- `modules/terraform.tf`: Terraform settings and required version
- `modules/providers.tf`: provider configuration
- `modules/variables.tf`: shared input variables

## Prerequisites

- Terraform `1.14.5` (aligned with CI)
- TFLint (for linting checks)

## Local Usage

Run from the `infra/` directory:

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
tflint --recursive
```

## CI Checks

The Terraform job in `.github/workflows/ci.yml` runs:

- Setup Terraform via `hashicorp/setup-terraform@v3`
- `terraform fmt -check -recursive`
- `terraform init -backend=false`
- `terraform validate`
- `tflint --recursive`
- `tfsec`

## TFLint Requirement

To avoid the `terraform_required_version` warning/error, keep this in `modules/terraform.tf`:

```hcl
terraform {
  required_version = "= 1.14.5"
}
```
