output "firewall_public_ip" {
  value       = aws_eip.fw_wan_eip.public_ip
  description = "L'adresse IP publique de l'Elastic IP rattachée au pare-feu"
}