provider "mongodbatlas" {
  # variable are provided via ENV
  # public_key = ""
  # private_key  = ""
}

variable "azure_subscription_id" {
  description = "Azure subscription for peering with ..."
  type = string
}

variable "azure_tenant_id" {
  description = "Azure subscription Directory ID"
  type = string
}

locals {
  # Atlas organization where to provsion a new group
  organization_id       = "599ef70e9f78f769464e3729"
  # New empty Atlas project name to create in organization
  project_id            = "Azure-Peered-project"  
  # Atlas cidr block 
  atlas_cidr_block      = "10.10.5.0/24"
  # A Azure resource group 
  resource_group_name   = "performance-test"
  # Associated Azure vnet
  vnet_name             = "atlas-peering-vnet"
  # Azure subnet for vnet
  address_space         = ["10.11.4.0/23"]
}

# Need a project
resource "mongodbatlas_project" "my_project" {
  name   = local.project_id
  org_id = local.organization_id
}

resource "mongodbatlas_network_container" "test" {
  project_id       = mongodbatlas_project.my_project.id
  atlas_cidr_block = local.atlas_cidr_block
  provider_name    = "AZURE"
  region           = "EUROPE_WEST"
  provisioner "local-exec" {
    command = "./setup-role.sh ${var.azure_subscription_id} ${local.resource_group_name} ${local.vnet_name} >> setup-role.output"
  }
}

resource "mongodbatlas_private_ip_mode" "my_private_ip_mode" {
  project_id = mongodbatlas_project.my_project.id 
  enabled    = true
}

# Peering for project Project 
resource "mongodbatlas_network_peering" "test" {
  project_id            = mongodbatlas_project.my_project.id
  atlas_cidr_block      = local.atlas_cidr_block
  container_id          = mongodbatlas_network_container.test.container_id
  provider_name         = "AZURE"
  azure_directory_id    = var.azure_tenant_id
  azure_subscription_id = var.azure_subscription_id
  resource_group_name   = local.resource_group_name
  vnet_name             = local.vnet_name

  depends_on = [mongodbatlas_private_ip_mode.my_private_ip_mode]
}

# Configure the Azure Provider
provider "azurerm" {
  # whilst the `version` attribute is optional, we recommend pinning to a given version of the Provider
  version = "=1.36.0"
  subscription_id = var.azure_subscription_id
  tenant_id = var.azure_tenant_id
}

# Create a resource group
resource "azurerm_resource_group" "atlas-group" {
  name     = local.resource_group_name
  location = "West Europe"
}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "atlas-group" {
  name                = local.vnet_name
  resource_group_name = azurerm_resource_group.atlas-group.name
  location            = azurerm_resource_group.atlas-group.location
  address_space       = local.address_space
}

resource "mongodbatlas_cluster" "test" {
  project_id   = mongodbatlas_project.my_project.id
  name         = "Performance-Test"
  num_shards   = 1

  replication_factor           = 3
  backup_enabled               = false
  auto_scaling_disk_gb_enabled = true
  mongo_db_major_version       = "4.2"

  //Provider Settings "block"
  provider_name               = "AZURE"  
  provider_disk_type_name     = "P6"
  provider_instance_size_name = "M10"
  provider_region_name        = "EUROPE_WEST"
}
