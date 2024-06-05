#!/bin/bash -x 
location="westus"
echo location= $location
owner="tecworkshop"
resourceGroupName=$owner-"fortiweb-"$location
imageName="fortinet:fortinet_fortiweb-vm_v5:fortinet_fw-vm:latest"
fortiwebUsername="azureuser"
fortiwebPassword='Welcome.123456!'
fortiwebvmdnslabel="$(whoami)fortiwebvm7"
secondaryIp="10.0.2.100"
echo $fortiwebvmdnslabel
echo fortiwebUsername=$fortiwebUsername
echo fortiwebPassword=$fortiwebPassword

vnetName="FortiWeb-VNET"
aksClusterName=$(whoami)-aks-cluster

function create_aks_cluster(){
az group create --location $location --resource-group $resourceGroupName

[ ! -f ~/.ssh/id_rsa ] && ssh-keygen -q -N "" -f ~/.ssh/id_rsa

az aks create \
    --name ${aksClusterName} \
    --node-count 1 \
    --vm-set-type VirtualMachineScaleSets \
    --network-plugin azure \
    --service-cidr  10.96.0.0/16 \
    --dns-service-ip 10.96.0.10 \
    --nodepool-name worker \
    --resource-group $resourceGroupName
az aks get-credentials -g  $resourceGroupName -n ${aksClusterName} --overwrite-existing
}

function get_aks_vnet_name(){
managedResourceGroup=$(az aks show --name $aksClusterName --resource-group $resourceGroupName --query "nodeResourceGroup" -o tsv)
echo $managedResourceGroup
az network vnet list --resource-group $managedResourceGroup -o table
aksvnetName=$(az network vnet list  --resource-group $managedResourceGroup --query "[0].name" -o tsv)
echo $aksvnetName
remoteVnetId=$(az network vnet show --resource-group $managedResourceGroup --name $aksvnetName --query "id" -o tsv)
echo "Remote VNet ID: $remoteVnetId"
}


function create_rg(){
az group create --name $resourceGroupName --location $location
}

function create_vnet(){ 
az network vnet create \
  --resource-group $resourceGroupName \
  --name $vnetName \
  --address-prefix 10.0.0.0/16 \
  --subnet-name ExternalSubnet \
  --subnet-prefix 10.0.1.0/24
}
function create_subnet() { 
az network vnet subnet create \
  --resource-group $resourceGroupName \
  --vnet-name $vnetName \
  --name InternalSubnet \
  --address-prefix 10.0.2.0/24
}

function create_nsg() {
az network nsg create \
  --resource-group $resourceGroupName \
  --name MyNSG

az network nsg rule create \
  --resource-group $resourceGroupName \
  --nsg-name MyNSG \
  --name AllowAll \
  --protocol '*' \
  --direction Inbound \
  --priority 1000 \
  --source-address-prefix '*' \
  --source-port-range '*' \
  --destination-address-prefix '*' \
  --destination-port-range '*'
}

function create_public_ip () {
az network public-ip create \
  --resource-group $resourceGroupName \
  --name FWBPublicIP \
  --allocation-method Static \
  --sku Standard \
  --dns-name $fortiwebvmdnslabel
} 

function create_nic() {
az network nic create \
  --resource-group $resourceGroupName \
  --name NIC1 \
  --vnet-name $vnetName \
  --subnet ExternalSubnet \
  --network-security-group MyNSG \
  --public-ip-address FWBPublicIP

az network nic update \
    --resource-group $resourceGroupName \
    --name NIC1 \
    --ip-forwarding true

az network nic create \
  --resource-group $resourceGroupName \
  --name NIC2 \
  --vnet-name $vnetName \
  --subnet InternalSubnet \
  --network-security-group MyNSG

az network nic update \
    --resource-group $resourceGroupName \
    --name NIC2 \
    --ip-forwarding true

# Add an IP alias to NIC2
#  az network nic ip-config update \
#    --resource-group $resourceGroupName \
#    --nic-name NIC2 \
#    --name ipconfig1 \
#    --private-ip-address $secondaryIp
} 

function create_vm() {
az vm create \
  --resource-group $resourceGroupName \
  --name MyFortiWebVM \
  --size Standard_F2s \
  --image $imageName \
  --admin-username $fortiwebUsername \
  --admin-password $fortiwebPassword \
  --nics NIC1 NIC2 \
  --location $location \
  --public-ip-address-dns-name $fortiwebvmdnslabel \
  --ssh-key-values @~/.ssh/id_rsa.pub

} 
function create_vnet_peering() {
localPeeringName="FortiWebToAksPeering"
remoteResourceGroup="MC"_${owner}-"fortiweb"-${location}_${aksClusterName}_${location}
remotePeeringName="AksToFortiWebPeering"
# Get the full resource ID of the local VNet
localVnetId=$(az network vnet show --resource-group $resourceGroupName --name $vnetName --query "id" -o tsv)
echo "Local VNet ID: $localVnetId"
# Get the full resource ID of the remote VNet
remoteVnetName=$(az network vnet list  --resource-group $remoteResourceGroup --query "[0].name" -o tsv)
remoteVnetId=$(az network vnet show --resource-group $remoteResourceGroup --name $remoteVnetName --query "id" -o tsv)
echo "Remote VNet ID: $remoteVnetId"
# Create peering from local VNet to remote VNet
az network vnet peering create \
  --name $localPeeringName \
  --resource-group $resourceGroupName \
  --vnet-name $vnetName \
  --remote-vnet $remoteVnetId \
  --allow-vnet-access
# Create peering from remote VNet to local VNet
az network vnet peering create \
  --name $remotePeeringName \
  --resource-group $remoteResourceGroup \
  --vnet-name $remoteVnetName \
  --remote-vnet $localVnetId \
  --allow-vnet-access
}

function get_aks_node_ip() {
nodeIp=$(kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')
echo $nodeIp
}

function check_vm_to_aks_connectivity() {
echo now check connectivity between fortiweb to aks node ip
ssh -o "StrictHostKeyChecking=no" azureuser@$fortiwebvmdnslabel.westus.cloudapp.azure.com execute ping $nodeIp
sleep 10
}

function create_secret_for_fortiweb() {
kubectl create secret generic fwb-login1 --from-literal=username=$fortiwebUsername --from-literal=password=$fortiwebPassword
}

function delete_resource() {
az group delete -g $resourceGroupName
}


create_rg
create_aks_cluster
create_vnet
create_subnet
create_nsg
create_public_ip
create_nic
create_vm
#get_aks_vnet_name
create_vnet_peering
echo $aksvnetName
create_secret_for_fortiweb
#delete_resource
get_aks_node_ip
check_vm_to_aks_connectivity
