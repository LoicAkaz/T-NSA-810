
---

# 📁 4️⃣ `ansible/README.md`

```markdown
# Configuration Management (Ansible)

## 📌 Purpose

This directory contains Ansible configuration used to configure all provisioned machines.

We use Ansible Pull mode.

---

## 🧠 Configuration Model

Each VM pulls configuration from this repository using:

```bash
ansible-pull -U https://github.com/<org>/T-NSA-810.git ansible/playbooks/site.yml