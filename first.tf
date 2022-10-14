terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
  required_version = "~>1.0"
}

provider "azurerm" {
  # Configuration options
  features {}
  alias           = "prod-team"                            #nickname
  subscription_id = "febbdafe-ca54-4914-8e49-77d353fdbb12" #subscription ID
  client_id       = "31aada00-a3c0-44f8-a101-ad1a681b7920" #appid
  client_secret   = "TrnhW72DpYSI8ubXL-pLO-R8p5vmSpD~H3"   #password
  tenant_id       = "cea297cb-9bde-428d-9a6e-48fa9c582ed6" #tenantID
}
resource "azurerm_resource_group" "example" { #reference name is unique for each resource type
  provider = azurerm.prod-team
  name     = "test-rg"
  location = "westus"
}
resource "azurerm_virtual_network" "example" {
  provider            = azurerm.prod-team
  name                = "test-network"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location #referencing arguments of another resource
  address_space       = ["10.0.0.0/8"]
}
resource "azurerm_subnet" "example" {
  provider             = azurerm.prod-team
  name                 = "test-subnet"
  virtual_network_name = azurerm_virtual_network.example.name
  resource_group_name  = azurerm_resource_group.example.name
  address_prefixes     = ["10.0.1.0/24"]
}
resource "azurerm_network_interface" "example" {
  provider            = azurerm.prod-team
  name                = "vm-nic"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  ip_configuration {
    name                          = "block1"
    subnet_id                     = azurerm_subnet.example.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example.id
    primary                       = true
  }
}
resource "azurerm_public_ip" "example" {
  provider            = azurerm.prod-team
  name                = "vm-public-ip"
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  allocation_method   = "Static"
}
resource "azurerm_linux_virtual_machine" "example" {
  provider                        = azurerm.prod-team
  name                            = "linux-machine"
  resource_group_name             = azurerm_resource_group.example.name
  location                        = azurerm_resource_group.example.location
  size                            = "Standard_DS2_v2"
  admin_username                  = "adminuser"
  admin_password                  = "ubuntu@1234!"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.example.id,
  ]


  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  provisioner "local-exec" {
    when       = create
    on_failure = continue #avoids tainting of resource
    command    = "echo ${azurerm_linux_virtual_machine.example.name} > vmname.txt"
  }
  provisioner "remote-exec" {
    when       = create
    on_failure = continue
    inline = [
      "sudo apt-get update -y",
      "sudo apt-get install nginx -y",
      "sudo systemctl enable nginx --now",
    ]
  }
  provisioner "remote-exec" {
    when       = destroy
    on_failure = continue
    inline = [
      "sudo systemctl stop nginx",
      "sudo apt-get remove nginx -y",
    ]
  }
  provisioner "file" {
    on_failure = continue
    #D:\terraform projects\clarence-tf\welcome.sh
    source      = "D:/terraform projects/clarence-tf/welcome.sh"
    destination = "/tmp/welcome.sh"
  }
  provisioner "remote-exec" {
    when       = create
    on_failure = continue
    inline = [
      "chmod +x /tmp/welcome.sh",
      "/tmp/welcome.sh",
      "rm /tmp/welcome.sh",
    ]
  }
  connection {
    type     = "ssh"
    user     = self.admin_username
    password = self.admin_password
    host     = self.public_ip_address
  }
}