# [cite_start]CIA - Deployment and Securing of a Hybrid Infrastructure [cite: 3]

## 📝 Description du Projet
[cite_start]Ce projet consiste à concevoir, déployer et sécuriser une infrastructure hybride composée de deux sites **Proxmox VE** (un site local et un site distant)[cite: 5, 12]. [cite_start]L'objectif est de créer une architecture évolutive, hautement disponible et entièrement automatisée via une approche **GitOps** utilisant **ansible-pull** et la **Stack Elastic** pour l'observabilité[cite: 19, 32].

## 🎯 Objectifs Principaux
* [cite_start]**Hybridation** : Déploiement de deux sites Proxmox interconnectés[cite: 12].
* [cite_start]**Sécurité Réseau** : Mise en place d'un VPN site-à-site sécurisé et de firewalls pfSense avec capacité de coupure d'urgence (*kill switch*)[cite: 13, 14, 22].
* [cite_start]**Accès Contrôlé** : Installation d'un bastion pour l'accès externe au site distant[cite: 15].
* [cite_start]**Gestion IPAM** : Automatisation de la gestion des adresses IP via **NetBox**[cite: 16, 41].
* [cite_start]**Observabilité** : Centralisation et analyse des logs avec la **Stack Elastic** complète[cite: 17, 43].
* [cite_start]**Segmentation** : Séparation stricte des trafics (Admin / Users / Services) et respect du principe du moindre privilège[cite: 21].

## 🛠️ Stack Technique
| Composant | Technologie | Description |
| :--- | :--- | :--- |
| **Virtualisation** | **Proxmox VE** | [cite_start]Solution bare-metal pour l'hébergement des VMs[cite: 37]. |
| **Firewall / Routage**| **pfSense** | [cite_start]Filtrage du trafic et réduction de l'exposition[cite: 45]. |
| **VPN** | **OpenVPN** | [cite_start]Interconnexion chiffrée site-à-site[cite: 39]. |
| **Configuration** | **Ansible (Pull)** | Gestion de configuration continue et automatisée via Git. |
| **IPAM** | **NetBox** | [cite_start]Source de vérité pour la gestion réseau[cite: 41]. |
| **Observabilité** | **Stack Elastic** | [cite_start]Analyse des logs et monitoring de l'infrastructure[cite: 43]. |

## ⚠️ Contraintes Techniques
* [cite_start]**Limitation des ressources** : Un maximum de **3 VMs** par site Proxmox est autorisé[cite: 69].
* [cite_start]**Disponibilité DNS** : Transfert DNS opérationnel entre les deux sites[cite: 64, 80].
* [cite_start]**Documentation** : Rédaction de **runbooks** détaillés pour la reconstruction complète de l'infrastructure[cite: 23, 33, 107].
* [cite_start]**Support** : Utilisation exclusive de stacks activement maintenues par la communauté[cite: 70].

## 📂 Structure du Dépôt
* `ansible/` : Playbooks et rôles pour le déploiement via **ansible-pull**.
* `pfsense/` : Configurations et règles de filtrage réseau.
* `elastic/` : Pipelines de logs et configurations Kibana.
* `netbox/` : Scripts d'automatisation pour l'IPAM.
* [cite_start]`docs/` : Diagrammes d'architecture et procédures de reprise d'activité (DRP)[cite: 106, 107].

---
[cite_start]*Ce projet est réalisé dans le cadre du cursus {EPITECH}[cite: 1, 113].*
