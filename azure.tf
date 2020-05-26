#################################################################
#          Terraform file depends on variables.tf               #
#################################################################

#################################################################
#          Terraform file depends on locals.tf                  #
#################################################################

# Some remaining variables are still hardcoded. Such virtual 
# machine details. There are only used once, and most likely they 
# are not required to change


#################################################################
#################### MICROSOFT AZURE SECTION ####################
#################################################################
provider "azurerm" {
  # whilst the `version` attribute is optional,
  # we recommend pinning to a given version of the Provider
  # version = "=1.36.0"
  version = "=2.1"
  subscription_id = var.azure_subscription_id
  tenant_id = var.azure_tenant_id
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "atlas-group" {
  name     = local.resource_group_name
  location = local.location
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "atlas-group" {
  name                = local.vnet_name
  resource_group_name = azurerm_resource_group.atlas-group.name
  location            = azurerm_resource_group.atlas-group.location
  address_space       = local.address_space
}

# Create a subnet in virtual network,
resource "azurerm_subnet" "atlas-group" {
  name                 = local.subnet
  address_prefix       = local.subnet_address_space
  resource_group_name  = azurerm_resource_group.atlas-group.name
  virtual_network_name = azurerm_virtual_network.atlas-group.name

}

resource "azurerm_public_ip" "demo-vm-ip" {
    name                         = "myPublicIP"
    location                     = local.location_alt
    resource_group_name          = azurerm_resource_group.atlas-group.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Atlas Demo"
    }
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "demo-vm-nsg" {
    name                = "myAtlasDemo"
    location            = local.location_alt
    resource_group_name = azurerm_resource_group.atlas-group.name

    # Allow inbound SSH traffic
    security_rule {
        name                       = "SSH"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment                = "Atlas Demo"
    }
}

# Create network interface
resource "azurerm_network_interface" "demo-vm-nic" {
    name                      = "myNIC"
    location                  = azurerm_network_security_group.demo-vm-nsg.location
    resource_group_name       = azurerm_resource_group.atlas-group.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.atlas-group.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.demo-vm-ip.id
    }

    tags = {
        environment = "Atlas Demo"
    }

    depends_on = [ azurerm_network_interface.demo-vm-nic ]
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "demo-vm" {
    network_interface_id      = azurerm_network_interface.demo-vm-nic.id
    network_security_group_id = azurerm_network_security_group.demo-vm-nsg.id
}

# Create virtual machine
resource "azurerm_virtual_machine" "demo-vm" {
    name                  = "demo-vm"
    location              = local.location_alt
    resource_group_name   = azurerm_resource_group.atlas-group.name
    network_interface_ids = [azurerm_network_interface.demo-vm-nic.id]
    vm_size               = "Standard_D2s_v3"

    storage_os_disk {     
        name              = "demo-OsDisk"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Standard_LRS"
    }

    #This will delete the OS disk and data disk automatically when deleting the VM
    delete_os_disk_on_termination = "true"

    storage_image_reference {
        publisher         = "Canonical"
        offer             = "UbuntuServer"
        sku               = "18.04-LTS"
        version           = "latest"
    }

    os_profile {
        computer_name     = "demo-vm"
        admin_username    = local.admin_username
        admin_password    = var.admin_password
    }


    os_profile_linux_config {
        disable_password_authentication = false
    #    ssh_keys {
    #        path          = "/home/eugeneb/.ssh/authorized_keys"
    #        key_data      = var.ssh_keys_data
    #    }
    }

    tags = {
        environment       = "Demo"
    }

    connection {
        type = "ssh"
        host = azurerm_public_ip.demo-vm-ip.ip_address
        user = local.admin_username
        password = var.admin_password
    #    private_key = file(var.private_key_path)
    }

#    provisioner "remote-exec" {
#        inline = [
#        "sleep 10",
#        "sudo apt-get -y update",
#        "sudo apt-get -y install python3-pip",
#        "sudo apt-get -y update",
##       "sudo apt-get -y install python3-pip",
#        "sudo pip3 install pymongo==3.9.0",
#        "sudo pip3 install faker",
#        "sudo pip3 install dnspython"
#        ]
#    }
}


