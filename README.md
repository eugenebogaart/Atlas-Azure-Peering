# MongoDB Atlas porject peered into Azure VNet 

# Background
Based on an small Proof of Concept to make Atlas available via VNet peering in Azure, this script was generalized to automate all steps. Assumption was to automate each step, including the scripts to define custom roles for peering.

# Prerequisites:
* Authenticate into Azure via CLI with:  az login

# Basic Terraform resources in script
* mongodbatlas_project,  creates an empty project in your Atlas account
* mongodbatlas_private_ip_mode,  switches prject to private IP mode so it can be used for peering
* mongodbatlas_network_container,  setup a container for peering (internal Atlas thing)
* mongodbatlas_network_peering,  setup actual peering
* azurerm_resource_group, create a Azure resource group to peer to
* azurerm_virtual_network, create a Azure Virtual Network  to peer into
* mongodbatlas_cluster, finally create cluster 

* Create a virtual machine Azure is left to the reader.  


# Configure Script

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


