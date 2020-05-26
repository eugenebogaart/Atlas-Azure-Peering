# MongoDB Atlas project peered into Azure VNet 

## Background
Based on an small Proof of Concept to make Atlas available via VNet peering in Azure in the same region, this script was generalized to automate all steps. Assumption was to automate each step, including the scripts to define custom roles for peering.  The documentation on how to do this in several manual steps is here: https://docs.atlas.mongodb.com/security-vpc-peering/

## Prerequisites:
* Authenticate into Azure via CLI with:  az login
* Have Terraform 0.12+ installed
* Run: terraform init 

```
Initializing provider plugins...
- Checking for available provider plugins...
- Downloading plugin for provider "azurerm" (hashicorp/azurerm) 1.36.0...
- Downloading plugin for provider "mongodbatlas" (terraform-providers/mongodbatlas) 0.3.1...
```

## Config:
* Set up credential, as in section: "Configure Script - Credentials"
* Change basic parameters, as in file : locals.tf
* Run: terraform apply

## Todo:
* Add a subnet to Azure Vnet
* ~~Create a Virtual Machine in Azure~~
* Install stuff on VM

## Basic Terraform resources in script
* mongodbatlas_project,  creates an empty project in your Atlas account
* mongodbatlas_private_ip_mode,  switches new project to private IP mode so it can be used for peering
* mongodbatlas_network_container,  setup a container for peering (internal Atlas thing)
* mongodbatlas_network_peering,  setup actual peering
* azurerm_resource_group, create a Azure resource group to hold vnet 
* azurerm_virtual_network, create a Azure Virtual Network to peer into
* mongodbatlas_cluster, finally create cluster 

* Create a virtual machine Azure is left to the reader.  


## Configure Script - Credentials: "varaibles.tf"

To configure the Terraform script, one needs public and private key setup for Atlas. 
These keys are expected in environment variables, or can be provide as command line 
parameters of added to a Terrafom Variable file. The MONGODBATLAS plugin will read
the 2 distinct variable, as below:

* MONGODB_ATLAS_PUBLIC_KEY=<PUBLICKEY>
* MONGODB_ATLAS_PRIVATE_KEY=<PRIVATEKEY>

Second a Azure subscription is required.  The primary attributes are also expected 
as environment variables. Values need to be provided in TF_VAR_ format.

* TF_VAR_azure_subscription_id=<SUBSCRIPTION_ID>
* TF_VAR_azure_tenant_id=<DIRECTORY_ID>

## Other configuration: "locals.tf"

In the locals resource or the Terraform file, several parameters should be adapted to your need
```
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
  location              = "West Europe"
  # Azure alt location (ips and sec groups use this)
  location_alt          = "westeurope"
  # Azure cidr block for vnet
  address_space         = ["10.11.4.0/23"]
  # Azure subnet in vnet
  subnet                = "subnet1"
  # Azure subnet cidr
  subnet_address_space  = "10.11.4.192/26"
  # Azure vm admin_user
  admin_username        = "myadmin"
}
```

## Setup-role.sh

While setting up peering requires several manual steps, such as running Azure CLI scripts. In the interactive Atlas Peering wizard the scripts must be copied/paste into the shell. Here these scripts are generated and called as shell scripts in between completion of Terraform resources. The scripts are run when resource: "mongodbatlas_network_container" is completed.  See below resource:

```
resource "mongodbatlas_network_container" "test" {
  project_id       = mongodbatlas_project.my_project.id
  atlas_cidr_block = local.atlas_cidr_block
  provider_name    = "AZURE"
  region           = local.region
  provisioner "local-exec" {
    command = "./setup-role.sh ${var.azure_subscription_id} ${local.resource_group_name} ${local.vnet_name} >> setup-role.output"
  }
}
```


## Known Bugs
* Some times the script ends with a complaint: External Azure subscription unreachable.
Just run it again.  It looks like a timing issue in the Azure API, where a resource is created but not available yet.
