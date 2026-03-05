# Infrastructure Automation & GitOps Strategy

## 1. Justifying GitOps "Pull" Mode

In this project, the **Pull Mode** is a strategic choice to ensure **Network Invisibility** and maintain a high security posture within the **Proxmox environment**.

### Firewall Stealth & Perimeter Security
By using Pull mode, the **pfSense firewall at Site B** maintains a **"Closed-Inbound" posture**. 
The Bastion initiates an **outbound connection to GitHub**; since firewalls are stateful, they allow the **return data (Ansible playbooks)** without requiring open ports (like `22` or `80`) to the public internet.

### NAT Traversal within Proxmox
Because the environment is **100% virtualized in Proxmox**, internal LANs (`10.0.41.0/24`) sit behind a **NAT**. 
External **Push systems** cannot reach these private IPs directly, but the **Pull runner**, sitting inside the network, bypasses NAT issues by communicating outward.

### Resilience to Intermittent Connectivity
If the **VPN tunnel** or internet connection drops, the **Pull runner** will automatically retry until the connection is restored, ensuring the environment eventually reaches the **Desired State** without manual intervention.

---

## 2. Defining GitHub as the "Source of Truth"

**GitHub** acts as the **Immutable Blueprint** of the entire hybrid infrastructure, moving management away from manual changes to **version-controlled code**.

### Declarative Desired State
Instead of manual **point-and-click configuration in Proxmox**, GitHub stores the **Ansible Playbooks** that define exactly how the system should look. 
This eliminates **Configuration Drift**, where servers slowly become inconsistent over time due to undocumented manual changes.

### Versioned Audit Trail
Every change to the network or a server requires a **commit**. 
This provides a perfect **historical record**: if a change breaks the connection between **Site A and Site B**, the team can identify the exact line of code responsible and **revert it instantly**.

### Disaster Recovery (DRP) Readiness
Because **100% of the configuration lives in GitHub**, the **Recovery Time Objective (RTO)** is near zero. 
If a **Proxmox node fails**, a new node can be spun up and the **"Truth" pulled from GitHub** to restore the entire site automatically.

---

## 3. The Role of the Bastion (as a Runner)

The **Bastion** is the **Privileged Execution Engine** that bridges the **version-controlled code in GitHub** with the actual **virtual hardware**.

### Internal Reachability & "Full Admin" Power
Standard cloud-based runners cannot see internal assets like:

- **NetBox** (`10.0.41.20`)
- **App_Server** (`192.168.41.20`)

By placing the **Ansible Runner on the Bastion with Full Admin rights**, it can execute commands directly across the **LAN** and through the **VPN tunnel** to configure every VM in the project.

### The "3-VM Rule" Optimization
To respect the strict **3-VM-per-site constraint**, the Bastion is designed to be **multi-functional**:

- **Human Entry Point** (SSH Jump Host)
- **Automation Runner** (Ansible execution)
- **Network Bridge** (DMZ to LAN)

### Secure Execution Environment
Since the Bastion resides in the **DMZ (VLAN 50)**, it provides a **controlled environment** to run automation. 
It pulls the **"Truth" from GitHub** and applies it to the **Production VLANs**, acting as the **only authorized administrator** allowed to modify the infrastructure.

---

## Summary Table for Project Scoping

| Task | Technical Reasoning | Project Impact |
| :--- | :--- | :--- |
| **GitOps Pull** | Outbound-only connectivity to GitHub API. | Maximizes pfSense effectiveness by closing inbound ports. |
| **GitHub Truth** | Versioned, declarative Ansible code. | Ensures 100% Reproducibility and Disaster Recovery. |
| **Bastion Runner** | Internal execution within the secure LAN. | Bypasses NAT/VPN barriers while respecting VM limits. |