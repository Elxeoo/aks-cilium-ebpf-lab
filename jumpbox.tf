resource "tls_private_key" "jumpbox_ssh" {
    algorithm = "RSA"
    rsa_bits = 4096
}

resource "azurerm_public_ip" "jumpbox_pip" {
    name = "pip-jumpbox"
    resource_group_name = azurerm_resource_group.rg.name
    location = var.location
    allocation_method = "Static"
    sku = "Standard"
}

resource "azurerm_network_security_group" "jumpbox_nsg" {
    name = "nsg-jumpbox"
    resource_group_name = azurerm_resource_group.rg.name
    location = var.location

    security_rule {
        name = "SSH"
        priority = 100
        direction = "Inbound"
        access = "Allow"
        protocol = "Tcp"
        source_address_prefix = "*"
        destination_address_prefix = "*"
        source_port_range = "*"
        destination_port_range = "22"
    }
}

resource "azurerm_subnet_network_security_group_association" "jumpbox_nsg_assoc" {
    network_security_group_id = azurerm_network_security_group.jumpbox_nsg.id
    subnet_id = azurerm_subnet.jumpbox_subnet.id
}

resource "azurerm_network_interface" "jumpbox_nic" {
    name = "nic-jumpbox"
    resource_group_name = azurerm_resource_group.rg.name
    location = var.location

    ip_configuration {
        name = "ipconfig-jumpbox"
        subnet_id = azurerm_subnet.jumpbox_subnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id = azurerm_public_ip.jumpbox_pip.id
    }
}

resource "azurerm_linux_virtual_machine" "jumpbox_vm" {
    name = "vm-jumpbox"
    resource_group_name = azurerm_resource_group.rg.name
    location = var.location
    admin_username = "azureuser"
    network_interface_ids = [azurerm_network_interface.jumpbox_nic.id]
    size = "Standard_D2s_v5"

    admin_ssh_key {
        username = "azureuser"
        public_key  = tls_private_key.jumpbox_ssh.public_key_openssh
    }

    os_disk {
        caching              = "ReadWrite"
        storage_account_type = "Standard_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer = "0001-com-ubuntu-server-jammy"
        sku = "22_04-lts"
        version = "latest"
    }
}