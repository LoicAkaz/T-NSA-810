variable "site_name" {
  type        = string
  description = "Le nom unique de ce site (ex: site-paris, site-lyon)"
}

variable "vpc_cidr" {
  type        = string
  description = "La plage IP globale du site (ex: 10.10.0.0/16)"
}

variable "public_subnet_cidr" {
  type        = string
  description = "La plage IP du réseau WAN (ex: 10.10.1.0/24)"
}

variable "private_subnet_cidr" {
  type        = string
  description = "La plage IP du réseau local LAN (ex: 10.10.2.0/24)"
}