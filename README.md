# MongoDB Atlas project peered into Azure VNet 

## What is new
* upgrade terrafrom to 0.13,  
* use Azurerm 2.36  
* use mongodbatlas 0.7  
* create Azure vm with Mongo shell

## Background
Based on an small Proof of Concept to make Atlas available via VNet peering in Azure in the same region, this script was generalized to automate all steps. Assumption was to automate each step, including the scripts to define custom roles for peering.  The documentation on how to do this in several manual steps is here: https://docs.atlas.mongodb.com/security-vpc-peering/

## Prerequisites:
* Authenticate into Azure via CLI with:  az login
* Have Terraform 0.13.5 installed
* Run: terraform init 

```
Initializing provider plugins...
- Checking for available provider plugins...
- Downloading plugin for provider "azurerm" (hashicorp/azurerm) e+.2.36...
- Downloading plugin for provider "mongodbatlas" (terraform-providers/mongodbatlas) 0.7.0...
```

## Config:
* Set up credential, as in section: "Configure Script - Credentials"
* Change basic parameters, as in file : locals.tf
* Run: terraform apply

## Todo <Nov 2020>:
* ~~Add a subnet to Azure Vnet~~
* ~~Create a Virtual Machine in Azure~~
* ~~Install stuff on VM~~

## Basic Terraform setup broken up in several files
* atlas.tf   creates Atlas side in a new project, VNet peering and small cluster
* azure.tf   creates Azure side for VNet peering, + one VM with Mongo shell installed
* locals.tf  here you can configure script to use meaning full name
* variables.tf  here you can attach credentials for Atlas, Azure and SSH


## Configure Script - Credentials: "variables.tf"

To configure the providers, such as Atlas and Azure, one needs credentials to gain access.
In case of MongoDB Atlas a public and private key pair is required. 
How to create an API key pair for an existing Atlas organization can be found here:
https://docs.atlas.mongodb.com/configure-api-access/#programmatic-api-keys
These keys are read in environment variables for safety. Alternatively these parameters
can be provide on the command line of the terraform invocation. The MONGODBATLAS provider will read
the 2 distinct variable, as below:

* MONGODB_ATLAS_PUBLIC_KEY=<PUBLICKEY>
* MONGODB_ATLAS_PRIVATE_KEY=<PRIVATEKEY>

Second a Azure subscription is required.  The primary attributes are also expected 
as environment variables. Values need to be provided in TF_VAR_ format.

* TF_VAR_azure_subscription_id=<SUBSCRIPTION_ID>
* TF_VAR_azure_tenant_id=<DIRECTORY_ID>

## Other configuration: "locals.tf"

In the locals resource of the locals.tf file, several parameters should be adapted to your needs
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
  admin_username        = "eugeneb"
  # Azure vm size
  azure_vm_size         = "Standard_F2"
  # Azure vm_name       
  azure_vm_name         = "demo"
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

## Give a go

In you favorite shell, run terraform apply and review the execution plan on what will be added, changed and detroyed. Acknowledge by typing: yes 

```
%>  terraform apply
```


## Known Bugs
* Some times the terraform deploy stops with a complaint: External Azure subscription unreachable.
Just run it again.  It looks like a timing issue in the Azure Provider and/or Azure API, where a resource is created but not yet available.
