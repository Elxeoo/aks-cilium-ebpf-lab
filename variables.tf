variable "location" {
  type        = string
  default     = "swedencentral"
  description = "Azure Region"
}

variable "vnet_address_space" {
  type    = list(string)
  default = ["10.200.0.0/16"]
}

variable "jumpbox_subnet_prefix" {
  type    = list(string)
  default = ["10.200.1.0/24"]
}

variable "aks_subnet_prefix" {
  type    = list(string)
  default = ["10.200.2.0/24"]
}

variable "admin_ip_range" {
  description = "Allowed IP range for jumpbox SSH access"
  type        = string
}