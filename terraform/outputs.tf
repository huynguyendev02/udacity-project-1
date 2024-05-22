output "access_ip" {
    value = "http://${azurerm_public_ip.public_ip.ip_address}"
    description = "Access IP to access the website"
}