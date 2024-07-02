#!/bin/bash -xe
location="westus"
echo "Location: $location"
owner="tecworkshop"
resourceGroupName="${owner}-$(whoami)-fortiweb-${location}-$(date -I)"
echo "Resource Group Name: $resourceGroupName"

create_publicIP_ssh() {
    az network public-ip create \
        --resource-group $resourceGroupName \
        --name fortiwebport2publicip \
        --sku Standard \
        --allocation-method static \
        --dns-name fwbmgmt
}

create_lb_fortiwebSSH() {
    az network lb create \
        --resource-group $resourceGroupName \
        --name fortiwebport2sshlb \
        --sku Standard \
        --public-ip-address fortiwebport2publicip \
        --frontend-ip-name fortiwebport2frontendip 
}

create_fortiweb_inbound_rule() {
    az network lb inbound-nat-rule create \
        --resource-group $resourceGroupName \
        --lb-name fortiwebport2sshlb \
        --name fortiwebsshrule \
        --frontend-ip-name fortiwebport2frontendip \
        --protocol Tcp \
        --frontend-port 22 \
        --backend-port 22 
}

update_fortiweb_inbound_rule() {
#    backendpoolname="fortiwebport2"
    backendipaddress="10.0.2.4"
vmName="MyFortiWebVM"
    vnetName="FortiWeb-VNET"
    ipConfigName="ipconfig1"
    
nic2ID=$(az vm show --resource-group $resourceGroupName --name $vmName --query "networkProfile.networkInterfaces[1].id" -o tsv)

az network nic ip-config inbound-nat-rule add \
    --resource-group $resourceGroupName \
    --nic-name $(basename $nic2ID) \
    --ip-config-name $ipConfigName \
    --lb-name fortiwebport2sshlb \
    --inbound-nat-rule fortiwebsshrule

} 
# Ensure the resource group is created

# Create the resources
create_publicIP_ssh
create_lb_fortiwebSSH
create_fortiweb_inbound_rule
update_fortiweb_inbound_rule
