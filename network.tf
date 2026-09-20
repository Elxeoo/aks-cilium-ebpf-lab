resource "azurerm_resource_group" "rg" {
  name     = "rg-aks-cilium-lab"
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-aks-lab"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  address_space       = var.vnet_address_space
}

resource "azurerm_subnet" "jumpbox_subnet" {
  name                 = "snet-jumpbox"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = var.jumpbox_subnet_prefix
}

resource "azurerm_subnet" "aks_subnet" {
  name                 = "snet-aks-nodes"
  virtual_network_name = azurerm_virtual_network.vnet.name
  resource_group_name  = azurerm_resource_group.rg.name
  address_prefixes     = var.aks_subnet_prefix
}