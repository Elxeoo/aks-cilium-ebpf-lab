resource "azurerm_kubernetes_cluster" "aks" {
    name = "aks-cilium-lab"
    location  = var.location
    resource_group_name = azurerm_resource_group.rg.name
    dns_prefix = "aks-cilium-lab"   
    private_cluster_enabled = true
    
    network_profile{
        network_plugin = "azure"
        network_plugin_mode = "overlay"
        network_data_plane = "cilium"
        network_policy = "cilium"
    }

    identity {
    type = "SystemAssigned"
    }

    default_node_pool {
        name  = "systempool"
        node_count = 1
        vm_size = "Standard_D2s_v5"
        vnet_subnet_id = azurerm_subnet.aks_subnet.id
    }

    node_provisioning_profile {
        mode = "Manual"
    }
}

  





    