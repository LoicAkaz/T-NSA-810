# CIA - Deployment and Securing of a Hybrid Infrastructure

## 📝 Description du Projet
Ce projet consiste à concevoir, déployer et sécuriser une infrastructure hybride composée de deux sites **Proxmox VE** (un site local et un site distant).L'objectif est de créer une architecture évolutive, hautement disponible et entièrement automatisée via une approche **GitOps** utilisant **ansible-pull** et la **Stack Elastic** pour l'observabilité.

## 🎯 Objectifs Principaux
* **Hybridation** : Déploiement de deux sites Proxmox interconnectés.
* **Sécurité Réseau** : Mise en place d'un VPN site-à-site sécurisé et de firewalls pfSense avec capacité de coupure d'urgence (*kill switch*).
* **Accès Contrôlé** : Installation d'un bastion pour l'accès externe au site distant.
* **Gestion IPAM** : Automatisation de la gestion des adresses IP via **NetBox**.
* **Observabilité** : Centralisation et analyse des logs avec la **Stack Elastic** complète.
* **Segmentation** : Séparation stricte des trafics (Admin / Users / Services) et respect du principe du moindre privilège.

## 🛠️ Stack Technique
| Composant | Technologie | Description |
| :--- | :--- | :--- |
| **Virtualisation** | **Proxmox VE** | Solution bare-metal pour l'hébergement des VMs. |
| **Firewall / Routage**| **pfSense** | Filtrage du trafic et réduction de l'exposition. |
| **VPN** | **OpenVPN** | Interconnexion chiffrée site-à-site. |
| **Configuration** | **Ansible (Pull)** | Gestion de configuration continue et automatisée via Git. |
| **IPAM** | **NetBox** | Source de vérité pour la gestion réseau. |
| **Observabilité** | **Stack Elastic** | Analyse des logs et monitoring de l'infrastructure. |

## ⚠️ Contraintes Techniques
* **Limitation des ressources** : Un maximum de **3 VMs** par site Proxmox est autorisé.
* **Disponibilité DNS** : Transfert DNS opérationnel entre les deux sites.
* **Documentation** : Rédaction de **runbooks** détaillés pour la reconstruction complète de l'infrastructure.
* **Support** : Utilisation exclusive de stacks activement maintenues par la communauté.

## 📂 Structure du Dépôt
* `ansible/` : Playbooks et rôles pour le déploiement via **ansible-pull**.
* `pfsense/` : Configurations et règles de filtrage réseau.
* `elastic/` : Pipelines de logs et configurations Kibana.
* `netbox/` : Scripts d'automatisation pour l'IPAM.
* `docs/` : Diagrammes d'architecture et procédures de reprise d'activité (DRP).

---
*Ce projet est réalisé dans le cadre du cursus {EPITECH}.*
