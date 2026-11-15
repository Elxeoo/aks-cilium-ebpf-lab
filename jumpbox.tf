resource "tls_private_key" "jumpbox_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "azurerm_public_ip" "jumpbox_pip" {
  name                = "pip-jumpbox"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "jumpbox_nsg" {
  name                = "nsg-jumpbox"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location

  security_rule {
    name                       = "SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.admin_ip_range
    destination_address_prefix = "*"
    source_port_range          = "*"
    destination_port_range     = "22"
  }
}

resource "azurerm_subnet_network_security_group_association" "jumpbox_nsg_assoc" {
  network_security_group_id = azurerm_network_security_group.jumpbox_nsg.id
  subnet_id                 = azurerm_subnet.jumpbox_subnet.id
}

resource "azurerm_network_interface" "jumpbox_nic" {
  name                = "nic-jumpbox"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location

  ip_configuration {
    name                          = "ipconfig-jumpbox"
    subnet_id                     = azurerm_subnet.jumpbox_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jumpbox_pip.id
  }
}

resource "azurerm_linux_virtual_machine" "jumpbox_vm" {
  name                  = "vm-jumpbox"
  resource_group_name   = azurerm_resource_group.rg.name
  location              = var.location
  admin_username        = "azureuser"
  network_interface_ids = [azurerm_network_interface.jumpbox_nic.id]
  size                  = "Standard_D2s_v5"

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.jumpbox_ssh.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # First boot: Azure CLI, plus kubectl from the same minor version as the cluster.
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    set -euo pipefail
    # apt-daily / unattended-upgrades can hold apt's locks on first boot.
    # dpkg lock: wait for it. Package-list lock (apt-get update ignores that timeout): retry.
    echo 'DPkg::Lock::Timeout "600";' > /etc/apt/apt.conf.d/99-lock-timeout
    apt_update() { for i in $(seq 30); do apt-get update && return 0; sleep 10; done; return 1; }
    apt_update
    apt-get install -y apt-transport-https ca-certificates curl gnupg
    curl -fsSL https://aka.ms/InstallAzureCLIDeb | bash
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v${var.kubernetes_version}/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${var.kubernetes_version}/deb/ /' > /etc/apt/sources.list.d/kubernetes.list
    apt_update
    apt-get install -y kubectl
  EOF
  )
}
