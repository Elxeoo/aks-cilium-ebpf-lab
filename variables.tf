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
  description = "CIDR allowed to SSH to the jumpbox, e.g. your public IPv4 as x.x.x.x/32."
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_ip_range, 0)) && var.admin_ip_range != "0.0.0.0/0"
    error_message = "admin_ip_range must be a CIDR such as 203.0.113.7/32, not * or 0.0.0.0/0."
  }
}

variable "kubernetes_version" {
  description = "AKS minor version. cloud-init installs kubectl from the same minor, so client and server never drift apart. Check `az aks get-versions -l <region>` before changing it."
  type        = string
  default     = "1.35"
}
