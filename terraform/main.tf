# --- 1. AWS PROVIDER ---
provider "aws" {
  region = "us-east-1"
}

# --- 2. AUTOMATIC PUBLIC IP DISCOVERY & KEY MANAGEMENT ---
# Importation automatique de la clé SSH locale vers le nouveau compte AWS
resource "aws_key_pair" "imported_key" {
  key_name   = "Master-Template-Preprod"
  public_key = file("Master-Template-Preprod.pem.pub")
}

# --- 3. DEFINITION OF THE SERVER FLEET ---
# This maps both your simulated On-Premise and Remote servers.
# To add or remove a server, you only change this list!
variable "preprod_servers" {
  type = map(object({
    role_name     = string
    site_location = string
  }))
  default = {
    "onprem-app" = { role_name = "Application", site_location = "Simulated-OnPrem" }
    "onprem-db"  = { role_name = "Database",    site_location = "Simulated-OnPrem" }
    "remote-git" = { role_name = "GitOps-Node",  site_location = "Remote-Cloud" }
    "remote-mon" = { role_name = "Monitoring",   site_location = "Remote-Cloud" }
  }
}

# --- 4. THE GLOBAL FIREWALL SHIELD ---
resource "aws_security_group" "preprod_global_sg" {
  name        = "nsa-preprod-global-sg-v2"
  description = "Security Group open for the preprod team"

  # Règle SSH ouverte à toute l'équipe (et au reste du monde)
  ingress {
    description = "SSH Access for the entire engineering team"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Ouvre l'accès SSH globalement
  }

  ingress {
    description = "HTTP Traffic for web applications"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- 5. THE AUTOMATED ENGINE (MULTIPLE EC2 INSTANCES) ---
resource "aws_instance" "preprod_fleet" {
  # Loops over the 'preprod_servers' map to create all 4 servers simultaneously
  for_each = var.preprod_servers

  # Official Ubuntu 22.04 LTS AMI for us-east-1 (ensures 'ubuntu' user and 'apt-get' works)
  ami           = "ami-080e1f13689e07408" 
  instance_type = "t3.micro"
  key_name      = "Master-Template-Preprod"

  vpc_security_group_ids = [aws_security_group.preprod_global_sg.id]

  # ZERO-EFFORT BOOTSTRAP: Executes right when the machine initializes
  user_data = <<-EOF
              #!/bin/bash
              # 1. Inject environment metadata onto the OS
              echo "ENV=preprod" > /etc/environment
              echo "ROLE=${each.value.role_name}" >> /etc/environment
              echo "LOCATION=${each.value.site_location}" >> /etc/environment
               
              # 2. Set distinct hostname
              hostnamectl set-hostname "preprod-${each.key}"

              # 3. Securely update and install core GitOps prerequisites
              apt-get update && apt-get install -y curl git software-properties-common
              apt-add-repository --yes --update ppa:ansible/ansible
              apt-get install -y ansible

              # 4. Trigger your automated configuration pipeline
              echo "Launching GitOps ansible-pull synchronization..." >> /var/log/user_data_bootstrap.log
              curl -s https://raw.githubusercontent.com/LoicAkaz/T-NSA-810/main/bootstrap.sh | bash >> /var/log/user_data_bootstrap.log 2>&1
              EOF

  tags = {
    Name        = "Preprod-${each.value.site_location}-${each.value.role_name}"
    Environment = "Preproduction"
    Site        = each.value.site_location
    Role        = each.value.role_name
  }
}

# --- 6. THE LIVESTREAMED DISPLAY (OUTPUTS) ---
# Prints out a clean dashboard of your servers and their new IPs right in your terminal
output "dashboard_preprod" {
  value = {
    for name, instance in aws_instance.preprod_fleet : 
    instance.tags["Name"] => "ssh -i Master-Template-Preprod.pem ubuntu@${instance.public_ip}"
  }
  description = "Ready-to-use SSH connection strings for your preprod architecture"
}
# ==============================================================================
# --- 7. EXTENSION : DÉPLOIEMENT DU NOUVEAU SITE SÉCURISÉ (SCALE UP) ---
# ==============================================================================

# Appel de notre module personnalisé pour créer le site autonome
module "nouveau_site_isole" {
  source              = "./modules/site_preprod"
  site_name           = "Site3-NSA"
  vpc_cidr            = "10.30.0.0/16"      # Plage IP réseau unique pour ce site
  public_subnet_cidr  = "10.30.1.0/24"      # Zone WAN (Où vit le pfSense)
  private_subnet_cidr = "10.30.2.0/24"      # Zone LAN (Où vivent les 2 Ubuntu)
}

# --- 8. DASHBOARD ADDITIONNEL POUR LE NOUVEAU SITE ---
output "dashboard_nouveau_site" {
  value = {
    "Etape_1" = "Connecte-toi d'abord au Pare-feu en WAN : ssh -i Master-Template-Preprod.pem ubuntu@${module.nouveau_site_isole.firewall_public_ip}"
    "Etape_2" = "Depuis le Pare-feu, tu pourras rebondir sur les 2 serveurs Ubuntu cachés dans le LAN"
  }
  description = "Informations d'accès pour votre nouveau site sécurisé"
}