terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

provider "azurerm" {
  skip_provider_registration = true
  features {}
  subscription_id = var.subscription_id
}

variable "tags" {
  type = map(string)
  default = {
    Project = "Udacity-1"
  }
}


data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "vnet" {
  name                = "udacity-vnet"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  address_space       = ["10.0.0.0/16"]
  tags = var.tags
}

resource "azurerm_subnet" "subnet" {
  name                 = "udacity-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  
}

resource "azurerm_network_security_group" "nsg" {
  name                = "udacity-nsg"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  tags = var.tags

}

resource "azurerm_network_security_rule" "nsg_rule_http" {
  name                        = "allow_http"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
  
}

resource "azurerm_subnet_network_security_group_association" "nsg_subet_association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "public_ip" {
  name                = "udacity-public-ip"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = var.location
  allocation_method   = "Static"
  tags = var.tags

}

resource "azurerm_lb" "lb" {
  name                = "udacity-lb"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
  tags = var.tags

}

resource "azurerm_lb_backend_address_pool" "lb_backend_pool" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "udacity-lb-be-vmas"
  
}

resource "azurerm_lb_rule" "lb_rule" {
  name                           = "udacity-lb-rule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "PublicIPAddress"

  loadbalancer_id                = azurerm_lb.lb.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.lb_backend_pool.id]
  
}

resource "azurerm_network_interface" "nic" {
  count               = var.vm_count
  name                = "udacity-nic-${count.index}"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
  tags = var.tags

}

resource "azurerm_network_interface_backend_address_pool_association" "bepool_nic_association" {
  count                   = var.vm_count
  network_interface_id    = element(azurerm_network_interface.nic.*.id, count.index)
  ip_configuration_name   = "ipconfig"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend_pool.id
}

resource "azurerm_availability_set" "aset" {
  name                = "udacity-aset"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.rg.name
  platform_fault_domain_count = 2
  platform_update_domain_count = 2
  tags = var.tags

}

resource "azurerm_linux_virtual_machine" "vms" {
  count                 = var.vm_count
  name                  = "vm-${count.index}"
  resource_group_name   = data.azurerm_resource_group.rg.name
  location              = var.location
  size                  = "Standard_B2ms"
  admin_username      = "udacity"
  admin_password = var.admin_password
  disable_password_authentication = false
  

  availability_set_id = azurerm_availability_set.aset.id
  
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }
  
  source_image_id = var.image_id
  tags = var.tags

}
