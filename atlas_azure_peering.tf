
variable "azure_subscription_id" {
  description = "Azure subscription for peering with ..."
  type = string
}

variable "azure_tenant_id" {
  description = "Azure subscription Directory ID"
  type = string
}

variable "ssh_keys_data" {
  description = "Public key"
  type = string
}

variable "private_key_path" {
  description = "Access path to private key"
  type = string
}

locals {
  # Atlas organization where to provsion a new group
  organization_id       = "599ef70e9f78f769464e3729"
  # New empty Atlas project name to create in organization
  project_id            = "Azure-Peered-project"
  # Atlas region, https://docs.atlas.mongodb.com/reference/microsoft-azure/#microsoft-azure
  region                = "EUROPE_WEST"
  # Atlas Pulic providor
  provider_name         = "AZURE"
  # Atlas cidr block
  atlas_cidr_block      = "10.10.5.0/24"
  # A Azure resource group
  resource_group_name   = "performance-test"
  # Associated Azure vnet
  vnet_name             = "atlas-peering-vnet"
  # Azure location
  location 		          = "West Europe"
  # Azure alt location (ips and sec groups use this)
  location_alt 		      = "westeurope"
  # Azure cidr block for vnet
  address_space         = ["10.11.4.0/23"]
  # Azure subnet in vnet
  subnet		            = "subnet1"
  # Azure subnet cidr
  subnet_address_space  = "10.11.4.192/26"
  # Azure vm admin_user
  admin_username	      = "eugeneb"
}

## Some remaining variables are still hardcoded,
#  There are only used once, and most likely they are not required to change

#################################################################
##################### MONGODB ATLAS SECTION #####################
#################################################################

provider "mongodbatlas" {
  # variable are provided via ENV
  # public_key = ""
  # private_key  = ""
  version = "~> 0.3"
}

# Need a project
resource "mongodbatlas_project" "proj1" {
  name   = local.project_id
  org_id = local.organization_id
}

resource "mongodbatlas_network_container" "test" {
  project_id       = mongodbatlas_project.proj1.id
  atlas_cidr_block = local.atlas_cidr_block
  provider_name    = local.provider_name
  region           = local.region
  provisioner "local-exec" {
    command = "./setup-role.sh ${var.azure_subscription_id} ${local.resource_group_name} ${local.vnet_name} >> setup-role.output"
  }
}

resource "mongodbatlas_private_ip_mode" "my_private_ip_mode" {
  project_id = mongodbatlas_project.proj1.id
  enabled    = true
}

# Peering for project Project
resource "mongodbatlas_network_peering" "test" {
  project_id            = mongodbatlas_project.proj1.id
  atlas_cidr_block      = local.atlas_cidr_block
  container_id          = mongodbatlas_network_container.test.container_id
  provider_name         = local.provider_name
  azure_directory_id    = var.azure_tenant_id
  azure_subscription_id = var.azure_subscription_id
  resource_group_name   = local.resource_group_name
  vnet_name             = local.vnet_name

  depends_on = [mongodbatlas_private_ip_mode.my_private_ip_mode]
}


resource "mongodbatlas_project_ip_whitelist" "test" {
    project_id = mongodbatlas_project.proj1.id

    whitelist {
      cidr_block = local.subnet_address_space
      comment    = "cidr block Azure subnet1"
    }
}

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
    location                  = local.location_alt
    resource_group_name       = azurerm_resource_group.atlas-group.name
    #network_security_group_id = azurerm_network_security_group.demo-vm-nsg.id

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.atlas-group.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.demo-vm-ip.id
    }

    tags = {
        environment = "Atlas Demo"
    }
}

