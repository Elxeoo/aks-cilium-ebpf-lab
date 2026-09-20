output "jumpbox_private_key" {
    value = tls_private_key.jumpbox_ssh.private_key_pem
    sensitive = true
}

output "jumpbox_public_ip" {
    value = azurerm_public_ip.jumpbox_pip.ip_address
    description = "Public IP address of the jumpbox VM"
}

output "aks_cluster_name" {
    value = azurerm_kubernetes_cluster.aks.name
}

output "aks_private_fqdn" {
    value = azurerm_kubernetes_cluster.aks.private_fqdn
}