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

- Versions are centralized in `.github/workflows/ci-versions.env`:
  - `TERRAFORM_VERSION`
  - `TFLINT_VERSION`
  - `TFSEC_VERSION`
- `modules/terraform.tf` must keep `required_version` aligned with `TERRAFORM_VERSION`.

## Local Usage

Run from the `infra/` directory:

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
tflint --recursive
tfsec .
```

## CI Checks

The Terraform job in `.github/workflows/ci.yml` runs:

- Setup Terraform via `hashicorp/setup-terraform@v3`
- `terraform fmt -check -recursive`
- `terraform init -backend=false`
- `terraform validate`
- `tflint --recursive`
- `tfsec .`

CI behavior:

- Workflow is triggered only when `infra/**`, `ansible/**`, or CI workflow/version files change.
- A `changes` job decides whether Terraform checks need to run.
- A `versions` job loads tool versions from `.github/workflows/ci-versions.env`.

## TFLint Requirement

To avoid the `terraform_required_version` warning/error, keep this in `modules/terraform.tf` and keep it synchronized with CI versions:

```hcl
terraform {
  required_version = "= 1.14.5"
}
```
