# Configuration Management (Ansible)

## Purpose

This directory contains Ansible inventories, playbooks, and shared variables used to configure provisioned machines.

## Structure

- `ansible.cfg`: local Ansible configuration
- `inventory/local.yml`: inventory for local environment
- `inventory/onprem.yml`: inventory for onprem environment
- `playbooks/site.yml`: shared entrypoint playbook
- `playbooks/local.yml`: local environment playbook
- `playbooks/onprem.yml`: onprem environment playbook
- `vars/all_variables.yml`: shared variables

## Local Usage

Run from the `ansible/` directory:

```bash
ansible-playbook -i inventory/local.yml playbooks/local.yml
ansible-playbook -i inventory/onprem.yml playbooks/onprem.yml
```

If you use pull mode on a target host:

```bash
ansible-pull -U https://github.com/<org>/T-NSA-810.git ansible/playbooks/site.yml
```

## CI Checks

The Ansible CI job in `.github/workflows/ci.yml` runs:

- `yamllint .`
- `ansible-lint .`

Versions used by CI are centralized in `.github/workflows/ci-versions.env`:

- `PYTHON_VERSION`
- `ANSIBLE_VERSION`
- `ANSIBLE_LINT_VERSION`
- `YAMLLINT_VERSION`

## Notes

- Some files are currently scaffolding and may be empty; complete inventories/playbooks before deployment.
- If you add a new lint or runtime dependency, pin it in CI and document it here.
