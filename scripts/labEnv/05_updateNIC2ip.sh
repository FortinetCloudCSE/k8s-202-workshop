#!/bin/bash

# Define variables
location="westus"
owner="tecworkshop"
resourceGroupName=$owner-$(whoami)-"fortiweb-"$location-$(date -I)
secondaryIp="10.0.2.100"
vmName="MyFortiWebVM"
nicName1="NIC1"
nicName2="NIC2"
fortiwebvmdnslabel="$(whoami)fortiwebvm7"
fortiwebvmdnslabelport2="$(whoami)px2"


az network public-ip create \
  --resource-group $resourceGroupName \
  --name FWBPublicIPPort2 \
  --allocation-method Static \
  --sku Standard \
  --dns-name $fortiwebvmdnslabelport2


# Add a secondary IP configuration to NIC2
az network nic ip-config create \
  --resource-group $resourceGroupName \
  --nic-name $nicName2 \
  --name ipconfigSecondary \
  --private-ip-address $secondaryIp \
  --public-ip-address FWBPublicIPPort2

# Attach NIC2 back to the VM
#az vm nic add \
#  --resource-group $resourceGroupName \
#  --vm-name $vmName \
#  --nics $nicName2

# Verify the secondary IP address
az network nic show \
  --resource-group $resourceGroupName \
  --name $nicName2 \
  --query "ipConfigurations[].privateIpAddress" \
  --output table

