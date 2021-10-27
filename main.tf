terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.46.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rg_carla_aula_fs" {
  name     = "rg_carla_aula_fs"
  location = "East US"
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "vm_carla_aula_fs" {
  name                = "vm_carla_aula_fs"
  resource_group_name = azurerm_resource_group.rg_carla_aula_fs.name
  location            = azurerm_resource_group.rg_carla_aula_fs.location
  address_space       = ["10.0.0.0/16"]
}
resource "azurerm_subnet" "sub_carla_aula_fs" {
  name                 = "sub_carla_aula_fs"
  resource_group_name  = azurerm_resource_group.rg_carla_aula_fs.name
  virtual_network_name = azurerm_virtual_network.vm_carla_aula_fs.name
  address_prefixes     = ["10.0.1.0/24"]
  
}

resource "azurerm_public_ip" "ip_carla_aula_fs" {
  name                = "ip_carla_aula_fs"
  resource_group_name = azurerm_resource_group.rg_carla_aula_fs.name
  location            = azurerm_resource_group.rg_carla_aula_fs.location
  allocation_method   = "Static"
}

data "azurerm_public_ip" "data_ip_carla_aula_fs"{
    resource_group_name = azurerm_resource_group.rg_carla_aula_fs.name
    name = azurerm_public_ip.ip_carla_aula_fs.name
}

resource "azurerm_resource_group" "example" {
  name     = "example-resources"
  location = "West Europe"
}

resource "azurerm_network_security_group" "nsg_carla_aula_fs" {
  name                = "nsg_carla_aula_fs"
  location            = azurerm_resource_group.rg_carla_aula_fs.location
  resource_group_name = azurerm_resource_group.rg_carla_aula_fs.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  

    security_rule {
    name                       = "mysql"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3306"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_interface" "ni_carla_aula_fs" {
  name                = "ni_carla_aula_fs"
  location            = azurerm_resource_group.rg_carla_aula_fs.location
  resource_group_name = azurerm_resource_group.rg_carla_aula_fs.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sub_carla_aula_fs.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.ip_carla_aula_fs.id
  }
}

resource "azurerm_network_interface_security_group_association" "nisg_carla_aula_fs" {
  network_interface_id      = azurerm_network_interface.ni_carla_aula_fs.id
  network_security_group_id = azurerm_network_security_group.nsg_carla_aula_fs.id
}



resource "azurerm_virtual_machine" "vmcarla"  {
  name                  = "vmcarla" 
  location              = azurerm_resource_group.rg_carla_aula_fs.location
  resource_group_name   = azurerm_resource_group.rg_carla_aula_fs.name
  network_interface_ids = [azurerm_network_interface.ni_carla_aula_fs.id]
  vm_size               = "Standard_DS1_v2"

 

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  storage_os_disk {
    name              = "diskcarla"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "vmcarla"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "staging"
  }
}

resource "time_sleep" "esperar_40_segundos" {
    depends_on = [
        azurerm_virtual_machine.vmcarla
    ]
    create_duration = "40s"
}

resource "null_resource" "install_mysql" {
    provisioner "remote-exec" {
        connection {
            type ="ssh"
            user = "testadmin"
            password = "Password1234!"
            host = data.azurerm_public_ip.data_ip_carla_aula_fs.ip_address
        }
        inline = [
            "sudo apt-get update",
            "sudo apt-get install -y mysql-server-5.7",
            "sudo mysql < /home/azureuser/mysql/script/user.sql",
            "sudo mysql < /home/azureuser/mysql/script/schema.sql",
            "sudo mysql < /home/azureuser/mysql/script/data.sql ",
            "sudo cp -f /home/azureuser/mysql/mysqld.cnf  /etc/mysql/mysql.conf.d/mysqld.cnf",
            "sudo service mysql restart",
            "sleep 20",           
        ]       
    }
     depends_on = [
        time_sleep.esperar_40_segundos
    ]   
}
