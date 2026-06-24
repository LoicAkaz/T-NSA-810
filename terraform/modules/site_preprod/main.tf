# ==============================================================================
# 1. ARCHITECTURE RÉSEAU DU SITE (VPC & SUBNETS)
# ==============================================================================

# Création du réseau isolé (VPC) pour ce site spécifique
resource "aws_vpc" "site_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "vpc-preprod-${var.site_name}"
  }
}

# Sous-réseau Public (Le WAN) : Là où réside la patte Internet du Pare-feu
resource "aws_subnet" "wan" {
  vpc_id                  = aws_vpc.site_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true # Donne automatiquement une IP publique aux ressources ici
  tags = {
    Name = "subnet-${var.site_name}-wan"
  }
}

# Sous-réseau Privé (Le LAN) : Zone ultra-sécurisée pour tes 2 serveurs Ubuntu
resource "aws_subnet" "lan" {
  vpc_id            = aws_vpc.site_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = "us-east-1a"
  tags = {
    Name = "subnet-${var.site_name}-lan"
  }
}

# ==============================================================================
# 2. PASSERELLES INTERNET & ROUTAGE (WAN & LAN)
# ==============================================================================

# Passerelle Internet pour le VPC (indispensable pour le WAN)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.site_vpc.id
  tags   = { Name = "igw-${var.site_name}" }
}

# IP Publique Statique (EIP) dédiée à notre passerelle NAT
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

# La Passerelle NAT classique AWS (permet au LAN de télécharger vers Internet)
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.wan.id # Elle doit être placée dans le WAN pour sortir
  tags          = { Name = "nat-gateway-${var.site_name}" }
}

# Table de routage du WAN : Envoie le trafic vers l'Internet Gateway
resource "aws_route_table" "wan_rt" {
  vpc_id = aws_vpc.site_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "rt-${var.site_name}-wan" }
}

# Table de routage du LAN : Envoie le trafic externe vers la Passerelle NAT
resource "aws_route_table" "lan_rt" {
  vpc_id = aws_vpc.site_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "rt-${var.site_name}-lan" }
}

# Associations des tables aux sous-réseaux correspondants
resource "aws_route_table_association" "wan_assoc" {
  subnet_id      = aws_subnet.wan.id
  route_table_id = aws_route_table.wan_rt.id
}

resource "aws_route_table_association" "lan_assoc" {
  subnet_id      = aws_subnet.lan.id
  route_table_id = aws_route_table.lan_rt.id
}

# ==============================================================================
# 3. SÉCURITÉ (SÉCURITY GROUP)
# ==============================================================================

resource "aws_security_group" "site_sg" {
  name        = "nsa-preprod-${var.site_name}"
  vpc_id      = aws_vpc.site_vpc.id
  description = "Security Group global pour le site ${var.site_name}"

  # Autorise le SSH (Port 22) pour que ton équipe puisse administrer le site
  ingress {
    description = "SSH Access for the engineering team"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Règle interne cruciale : autorise toutes les machines du VPC à se parler entre elles
  ingress {
    description = "Allow all internal VPC traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # Sortie totale autorisée vers Internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==============================================================================
# 4. MACHINE 1 : LE PARE-FEU (CONCEPTION DE TON PF_SENSE GRATUIT)
# ==============================================================================

# Carte Réseau 1 : Connectée au WAN (Internet public)
resource "aws_network_interface" "fw_wan" {
  subnet_id       = aws_subnet.wan.id
  security_groups = [aws_security_group.site_sg.id]
  tags            = { Name = "interface-${var.site_name}-fw-wan" }
}

# Carte Réseau 2 : Connectée au LAN (Réseau privé interne)
resource "aws_network_interface" "fw_lan" {
  subnet_id         = aws_subnet.lan.id
  security_groups   = [aws_security_group.site_sg.id]
  source_dest_check = false # INDISPENSABLE : dit à AWS de laisser cette carte router du trafic pour d'autres machines
  tags              = { Name = "interface-${var.site_name}-fw-lan" }
}

# IP Publique Statique (Elastic IP) dédiée à la patte WAN du Pare-feu
resource "aws_eip" "fw_wan_eip" {
  domain            = "vpc"
  network_interface = aws_network_interface.fw_wan.id
  tags              = { Name = "eip-${var.site_name}-fw-wan" }
}

# L'instance du Pare-feu (Simulation pfSense gratuite)
resource "aws_instance" "firewall" {
  ami           = "ami-080e1f13689e07408" # Image Ubuntu officielle stable
  instance_type = "t3.micro"
  key_name      = "Master-Template-Preprod" # Utilise ta nouvelle clé importée automatique

  # On attache la carte WAN en premier (index 0)
  network_interface {
    network_interface_id = aws_network_interface.fw_wan.id
    device_index         = 0
  }

  # On attache la carte LAN en deuxième (index 1)
  network_interface {
    network_interface_id = aws_network_interface.fw_lan.id
    device_index         = 1
  }

  tags = {
    Name = "Preprod-${var.site_name}-Firewall-pfSense"
  }
}

# ==============================================================================
# 5. MACHINES 2 & 3 : LES SERVEURS UBUNTU DANS LE LAN PRIVÉ
# ==============================================================================

resource "aws_instance" "lan_servers" {
  count         = 2 # Crée automatiquement 2 serveurs identiques
  ami           = "ami-080e1f13689e07408"
  instance_type = "t3.micro"
  key_name      = "Master-Template-Preprod"
  
  subnet_id              = aws_subnet.lan.id # Placés de force dans la zone sécurisée LAN
  vpc_security_group_ids = [aws_security_group.site_sg.id]

  # Configuration automatique à l'allumage (Idéal GitOps / Ansible)
  user_data = <<-EOF
              #!/bin/bash
              echo "ENV=preprod" > /etc/environment
              echo "ROLE=LAN-Server" >> /etc/environment
              echo "LOCATION=${var.site_name}" >> /etc/environment
              hostnamectl set-hostname "preprod-${var.site_name}-ubuntu-${count.index + 1}"
              apt-get update && apt-get install -y curl git software-properties-common
              apt-add-repository --yes --update ppa:ansible/ansible
              apt-get install -y ansible
              EOF

  tags = {
    Name = "Preprod-${var.site_name}-Ubuntu-Server-${count.index + 1}"
  }
}