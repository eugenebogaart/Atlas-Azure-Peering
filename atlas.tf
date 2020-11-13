#################################################################
#          Terraform file depends on variables.tf               #
#################################################################

#################################################################
#          Terraform file depends on locals.tf                  #
#################################################################

# Some remaining variables are still hardcoded, such Atlas shape 
# details. There are only used once, and most likely they are 
# not required to change

#################################################################
##################### MONGODB ATLAS SECTION #####################
#################################################################

provider "mongodbatlas" {
  # variable are provided via ENV
  # public_key = ""
  # private_key  = ""
  version = "~>0.7"
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

# As per April 1st, 2020 Peering Only mode is explict for legacy clusters
# 
#resource "mongodbatlas_private_ip_mode" "my_private_ip_mode" {
#  project_id = mongodbatlas_project.proj1.id
#  enabled    = true
#}

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

# See above node on Peering only for Azure
  # depends_on = [mongodbatlas_private_ip_mode.my_private_ip_mode]
}


resource "mongodbatlas_project_ip_whitelist" "test" {
    project_id = mongodbatlas_project.proj1.id

    cidr_block = local.subnet_address_space
    comment    = "cidr block Azure subnet1"
}

resource "mongodbatlas_cluster" "this" {
  name                  = "example"
  project_id            = mongodbatlas_project.proj1.id

  replication_factor           = 3
  # not allowed for version 4.2 clusters and above
  # backup_enabled               = true
  provider_backup_enabled      = true
  auto_scaling_disk_gb_enabled = true
  mongo_db_major_version       = "4.2"

  provider_name               = local.provider_name
  provider_instance_size_name = "M10"
  # this provider specific, why?
  provider_region_name        = local.region

  depends_on = [ mongodbatlas_network_peering.test ]
}


