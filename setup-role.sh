#!/bin/sh

# General documentation of MSFT to explain the below script:
# https://docs.microsoft.com/en-us/azure/virtual-network/virtual-network-manage-peering#permissions

echo $1 $2 $3

# this might create an error, because it is only needed once!

# Set up a service principle: to Allow the application to access cloudpeering-prod on behalf of the signed-in user.

az ad sp create --id e90a1407-55c3-432d-9cb1-3638900a9d22

cat <<EOF > peering-role.json
{
    "Name": "AtlasPeering/${1}/${2}/${3}",
    "IsCustom": true,
    "Description": "Grants MongoDB access to manage peering connections on network /subscriptions/${1}/resourceGroups/${2}/providers/Microsoft.Network/virtualNetworks/${3}",
    "Actions": [
        "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/read",
        "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/write",
        "Microsoft.Network/virtualNetworks/virtualNetworkPeerings/delete",
        "Microsoft.Network/virtualNetworks/peer/action"
    ],
    "AssignableScopes": [
        "/subscriptions/${1}/resourceGroups/${2}/providers/Microsoft.Network/virtualNetworks/${3}"
    ]
}
EOF

 az role definition create --role-definition peering-role.json

 az role assignment create --role "AtlasPeering/${1}/${2}/${3}" --assignee "e90a1407-55c3-432d-9cb1-3638900a9d22" --scope "/subscriptions/${1}/resourceGroups/${2}/providers/Microsoft.Network/virtualNetworks/${3}"


echo $?
