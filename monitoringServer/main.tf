terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "3.68.0"
    }
  }
}

provider "azurerm" {
  subscription_id = local.envs["subscription_id"]
  client_id       = local.envs["client_id"]
  client_secret   = local.envs["client_secret"]
  tenant_id       = local.envs["tenant_id"]

  features {}
}


resource "azurerm_resource_group" "monitoring_server_resource_group" {
  name     = "monitoring_server_group"
  location = "West Europe"
}

resource "azurerm_virtual_network" "monitoring_server_vn" {
  name                = "monitoring_server_network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.monitoring_server_resource_group.location
  resource_group_name = azurerm_resource_group.monitoring_server_resource_group.name
}

resource "azurerm_subnet" "monitoring_server_subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.monitoring_server_resource_group.name
  virtual_network_name = azurerm_virtual_network.monitoring_server_vn.name
  address_prefixes     = ["10.0.2.0/24"]
}

resource "azurerm_network_interface" "monitoring_server_interface" {
  name                = "monitoring-server-nic"
  location            = azurerm_resource_group.monitoring_server_resource_group.location
  resource_group_name = azurerm_resource_group.monitoring_server_resource_group.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.monitoring_server_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_public_ip" "public_ip" {
  name                = "myvmconnect"
  resource_group_name = azurerm_resource_group.monitoring_server_resource_group.name
  location            = azurerm_resource_group.monitoring_server_resource_group.location
  allocation_method   = "Static"
}


resource "azurerm_linux_virtual_machine" "monitoring-server" {
  name                = "monitoring-server"
  resource_group_name = azurerm_resource_group.monitoring_server_resource_group.name
  location            = azurerm_resource_group.monitoring_server_resource_group.location
  size                = "Standard_DS1_v2"
  admin_username      = "khalil"
  network_interface_ids = [
    azurerm_network_interface.monitoring_server_interface.id,
  ]

  admin_ssh_key {
    username   = "khalil"
    public_key = file("~/.ssh/id_rsa.pub")
  }
 
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
  
  connection {
    host = "${azurerm_public_ip.public_ip.ip_address}"
    user = "khalil"
    type = "ssh"
    private_key = file("~/.ssh/id_rsa")
  }
}

output "server_ip_address" {
  value  = "${azurerm_public_ip.public_ip.ip_address}"
}
