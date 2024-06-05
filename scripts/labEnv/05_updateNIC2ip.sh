#!/bin/bash

# Define variables
location="westus"
owner="tecworkshop"
resourceGroupName=$owner-$(whoami)-"fortiweb-"$location-$(date -I)
secondaryIp="10.0.2.100"
vmName="MyFortiWebVM"
nicName1="NIC1"
nicName2="NIC2"

# Remove NIC2 from the VM
#az vm nic remove \
#  --resource-group $resourceGroupName \
#  --vm-name $vmName \
#  --nics $nicName2

# Add a secondary IP configuration to NIC2
az network nic ip-config create \
  --resource-group $resourceGroupName \
  --nic-name $nicName2 \
  --name ipconfigSecondary \
  --private-ip-address $secondaryIp

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

