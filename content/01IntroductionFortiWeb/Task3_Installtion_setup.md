---
title: "Install and Setup FortiWeb Ingress Controller"
linkTitle: "Installation and Setup"
weight: 30
---

#### Network Diagram
In this chapter, we are going to create a lab setup as illustrated in the network diagram below.

FortiWeb can be configured with two ports: port1 for incoming traffic and port2 for proxy traffic to the backend application. This is called the twoarms mode here.

**FortiWeb TwoLegs Mode**
![FortiWeb with two ports](../images/fortiwebtwoarms.png)

FortiWeb can also be configured with a single port, where port1 handles both incoming traffic and proxy traffic to the backend application. This is called the one-arm mode.

**FortiWeb OneArm Mode**
![FortiWeb with single port](../images/fortiwebonearm.png)

{{% notice note %}}
In this workshop, please use **default onearm mode**. 
{{% /notice %}}

#### 1. Prepare Environment Variables


```bash
read -p "Enter deploy mode (twoarms/onearm) [onearm]: " fortiwebdeploymode
fortiwebdeploymode=${fortiwebdeploymode:-onearm}
echo $fortiwebdeploymode 
if [ "$fortiwebdeploymode" == "twoarms" ]; then
    secondaryIp="10.0.2.100"
else
    secondaryIp="10.0.1.100"
fi
owner="tecworkshop"
currentUser=$(az account show --query user.name -o tsv)
resourceGroupName=$(az group list --query "[?contains(name, '$(whoami)') && contains(name, 'workshop')].name" -o tsv)
#resourceGroupName=$(az group list --query "[?tags.UserPrincipalName=='$currentUser'].name" -o tsv)
if [ -z "$resourceGroupName" ]; then
    resourceGroupName=$owner-$(whoami)-"FortiWeb-"$location-$(date -I)
    az group create --name $resourceGroupName --tags UserPrincipalName=$currentUser --location $location
    resourceGroupName=$resourceGroupName
fi
location=$(az group show --name $resourceGroupName --query location -o tsv)
echo "Using resource group $resourceGroupName in location $location"

cat << EOF | tee > $HOME/variable.sh
#!/bin/bash -x
vnetName="FortiWeb-VNET"
aksVnetName="AKS-VNET"
imageName="fortinet:fortinet_FortiWeb-vm_v5:fortinet_fw-vm:latest"
FortiWebUsername="azureuser"
FortiWebPassword='Welcome.123456!'
FortiWebvmdnslabel="$(whoami)FortiWebvm7"
aksClusterName=$(whoami)-aks-cluster
rsakeyname="id_rsa_tecworkshop"
vm_name="$(whoami)FortiWebvm7.${location}.cloudapp.azure.com"
FortiWebvmdnslabelport2="$(whoami)px2"
svcdnsname="$(whoami)px2.${location}.cloudapp.azure.com"
remoteResourceGroup="MC"_${resourceGroupName}_$(whoami)-aks-cluster_${location} 
nicName1="NIC1"
nicName2="NIC2"
alias k=kubectl
EOF
echo FortiWebdeploymode=$FortiWebdeploymode >> $HOME/variable.sh
echo secondaryIp=$secondaryIp >> $HOME/variable.sh
echo location=$location >> $HOME/variable.sh
echo owner=$owner >> $HOME/variable.sh
echo resourceGroupName=$resourceGroupName >> $HOME/variable.sh
chmod +x $HOME/variable.sh
line='if [ -f "$HOME/variable.sh" ]; then source $HOME/variable.sh ; fi'
grep -qxF "$line" ~/.bashrc || echo "$line" >> ~/.bashrc
source $HOME/variable.sh
$HOME/variable.sh
if [ -f $HOME/.ssh/known_hosts ]; then 
grep -qxF "$vm_name" "$HOME/.ssh/known_hosts"  && ssh-keygen -R "$vm_name"
fi
```

#### 2. Create Kubernetes Cluster

We can use either managed K8s like AKS, EKS  or self-managed k8s like kubeadm etc., in this workshop, let's use AKS. 

We will create aks VNET and FortiWeb VNET in same resourceGroup, in reality, you can also create them in different resourceGroup. 

{{< tabs title="Create K8s cluster" >}}
{{% tab title="Vnet" %}}
- **Create aks VNET and subnet**

```bash
az network vnet create -g $resourceGroupName  --name  $aksVnetName --location $location  --subnet-name aksSubnet --subnet-prefix 10.224.0.0/24 --address-prefix 10.224.0.0/16
```
{{% /tab %}}
{{% tab title="subnetId" %}}
- **Get aksSubnetId** 

this aksSubnetId will be need when create AKS. 

```bash
aksSubnetId=$(az network vnet subnet show \
  --resource-group $resourceGroupName \
  --vnet-name $aksVnetName \
  --name aksSubnet \
  --query id -o tsv)
echo $aksSubnetId
```
{{% /tab %}}
{{% tab title="Create Cluster" %}}

- **Create AKS cluster** 

**this may take a while to complete**

```bash
[ ! -f ~/.ssh/$rsakeyname ] && ssh-keygen -t rsa -b 4096 -q -N "" -f ~/.ssh/$rsakeyname

az aks create \
    --name ${aksClusterName} \
    --node-count 1 \
    --vm-set-type VirtualMachineScaleSets \
    --network-plugin azure \
    --location $location \
    --service-cidr  10.96.0.0/16 \
    --dns-service-ip 10.96.0.10 \
    --nodepool-name worker \
    --resource-group $resourceGroupName \
    --kubernetes-version 1.28.9 \
    --vnet-subnet-id $aksSubnetId \
    --only-show-errors \
    --ssh-key-value ~/.ssh/${rsakeyname}.pub
az aks get-credentials -g  $resourceGroupName -n ${aksClusterName} --overwrite-existing
```

{{% /tab %}}
{{% tab title="Verify" %}}
Check Creation result with 
```
kubectl get node  -o wide
```
- You should see nodes are in "ready" status and "VERSION" is v.1.28.9, 
- The node should have an internal ip assigned. 

```
NAME                             STATUS   ROLES   AGE     VERSION   INTERNAL-IP   EXTERNAL-IP   OS-IMAGE             KERNEL-VERSION      CONTAINER-RUNTIME
aks-worker-12061195-vmss000000   Ready    agent   8m51s   v1.28.9   10.224.0.4    <none>        Ubuntu 22.04.4 LTS   5.15.0-1064-azure   containerd://1.7.15-1
```
{{% /tab %}}
{{% tab title="check AKS VNet" %}}

Check the Vnet of this aks cluster.

```bash
az network vnet list -g $resourceGroupName -o table
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}

you will find azure created  a Vnet for this AKS.
```
k8s51 [ ~ ]$ az network vnet list -g $resourceGroupName -o table
Name      ResourceGroup          Location    NumSubnets    Prefixes       DnsServers    DDOSProtection    VMProtection
--------  ---------------------  ----------  ------------  -------------  ------------  ----------------  --------------
AKS-VNET  k8s51-k8s101-workshop  eastus      1             10.224.0.0/16                False
```
{{% /tab %}}
{{< /tabs >}}

#### 3. Prepare to deploy FortiWeb VM in dedicated VNET 

In this workshop, We are going to deploy FortiWeb VM in it's own VNET, FortiWeb will use twoarms or onearm  deployment model, below lists the components going to be deployed 
- VNET : 10.0.0.0/16 
- Subnet1: 10.0.1.0/24
- Subnet2: 10.0.2.0/24 when FortiWeb in twoarms mode
- NSG : allow all traffic 
- NIC1 with Public IP for SSH access and Management, in Subnet1
- NIC2 for internal traffic, in Subnet2, when FortiWeb in twoarms mode
- VM with Extra DISK for log

{{< tabs title="network prep">}}
{{% tab title="subnet1" %}}

- **Create VNET with Subnet1**
```bash
az network vnet create \
  --resource-group $resourceGroupName \
  --name $vnetName \
  --location $location \
  --address-prefix 10.0.0.0/16 \
  --subnet-name ExternalSubnet \
  --subnet-prefix 10.0.1.0/24
```
{{% /tab %}}
{{% tab title="subnet 2" style="warning"%}}
- **Create Subnet2 in same VNET if use twoarms mode**

{{% notice warning %}} This is only for Two arm mode, if one arm mode dont run the below commands {{% /notice %}}

```bash
if [ "$FortiWebdeploymode" == "twoarms" ]; then 
az network vnet subnet create \
  --resource-group $resourceGroupName \
  --vnet-name $vnetName \
  --name InternalSubnet \
  --address-prefix 10.0.2.0/24
fi
```
{{% /tab %}}
{{% tab title="NSG" %}}
- **Create NSG with Rule**

this NSG will be attached to FortiWeb VM NICs.

```bash
az network nsg create \
  --resource-group $resourceGroupName \
  --location $location \
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
```
{{% /tab %}}
{{% tab title="PubIP" %}}
- **Create PublicIP with a DNS name**

this publicip serve for mgmt purpose, we can use this ip for SSH and WebGUI to FortiWeb VM via IP address or DNS name

the FortiWeb factory default configuration only have SSH service and WebGUI service enabled on Port1. so this Public IP will be associated to FortiWeb VM Port1. 

```bash
az network public-ip create \
  --resource-group $resourceGroupName \
  --location $location \
  --name FWBPublicIP \
  --allocation-method Static \
  --sku Standard \
  --dns-name $FortiWebvmdnslabel \
  --only-show-errors 
```
{{% /tab %}}
{{% tab title="NIC1" %}}
- **Create NIC1 and attach PublicIP**

```bash
az network nic create \
  --resource-group $resourceGroupName \
  --location $location \
  --name NIC1 \
  --vnet-name $vnetName \
  --subnet ExternalSubnet \
  --network-security-group MyNSG \
  --public-ip-address FWBPublicIP

az network nic update \
    --resource-group $resourceGroupName \
    --name NIC1 \
    --ip-forwarding true

```
{{% /tab %}}
{{% tab title="NIC2" style="warning" %}}
- **Create NIC2 if Fortiweb use twoarms mode**

{{% notice warning %}} This is only for Two arm mode, if one arm mode dont run the below commands {{% /notice %}}

```bash
if [ "$FortiWebdeploymode" == "twoarms" ]; then 
az network nic create \
  --resource-group $resourceGroupName \
  --location $location \
  --name NIC2 \
  --vnet-name $vnetName \
  --subnet InternalSubnet \
  --network-security-group MyNSG

az network nic update \
    --resource-group $resourceGroupName \
    --name NIC2 \
    --ip-forwarding true
fi 
```
{{% /tab %}}
{{< /tabs >}}

#### 4. Deploy FortiWeb VM 

{{< tabs title="FWeb VM">}}
{{% tab title="VM & storage" %}}
- **Create VM with storage Disk**

```bash
if [ "$FortiWebdeploymode" == "twoarms" ]; then 
nics="NIC1 NIC2" 
else
nics="NIC1"
fi

az vm create \
  --resource-group $resourceGroupName \
  --name MyFortiWebVM \
  --size Standard_F2s \
  --image $imageName \
  --admin-username $FortiWebUsername \
  --admin-password $FortiWebPassword \
  --nics $nics \
  --location $location \
  --public-ip-address-dns-name $FortiWebvmdnslabel \
  --data-disk-sizes-gb 30 \
  --ssh-key-values @~/.ssh/${rsakeyname}.pub \
  --only-show-errors
```

{{% /tab %}}
{{% tab title="twoarms" style="warning" %}}
you shall see output like this  if FortiWeb in twoarms mode

```
{
  "fqdns": "k8s51FortiWebvm7.eastus.cloudapp.azure.com",
  "id": "/subscriptions/02b50049-c444-416f-a126-3e4c815501ac/resourceGroups/k8s51-k8s101-workshop/providers/Microsoft.Compute/virtualMachines/MyFortiWebVM",
  "location": "eastus",
  "macAddress": "60-45-BD-D8-14-AF,60-45-BD-D8-1D-FE",
  "powerState": "VM running",
  "privateIpAddress": "10.0.1.4,10.0.2.4",
  "publicIpAddress": "13.90.210.29",
  "resourceGroup": "k8s51-k8s101-workshop",
  "zones": ""
}

```

{{% /tab %}}
{{% tab title="Check Resources" %}}

- **Check all the resource you created**

```bash
az resource list -g $resourceGroupName -o table
```

you shall see output like 

```
k8s51 [ ~ ]$ az resource list -g $resourceGroupName -o table
Name                                                    ResourceGroup          Location    Type                                        Status
------------------------------------------------------  ---------------------  ----------  ------------------------------------------  --------
AKS-VNET                                                k8s51-k8s101-workshop  eastus      Microsoft.Network/virtualNetworks
k8s51-aks-cluster                                       k8s51-k8s101-workshop  eastus      Microsoft.ContainerService/managedClusters
FortiWeb-VNET                                           k8s51-k8s101-workshop  eastus      Microsoft.Network/virtualNetworks
MyNSG                                                   k8s51-k8s101-workshop  eastus      Microsoft.Network/networkSecurityGroups
FWBPublicIP                                             k8s51-k8s101-workshop  eastus      Microsoft.Network/publicIPAddresses
NIC1                                                    k8s51-k8s101-workshop  eastus      Microsoft.Network/networkInterfaces
NIC2                                                    k8s51-k8s101-workshop  eastus      Microsoft.Network/networkInterfaces
MyFortiWebVM                                            k8s51-k8s101-workshop  eastus      Microsoft.Compute/virtualMachines
MyFortiWebVM_disk2_1a5d56afec9745dba51cfed47fd133dc     K8S51-K8S101-WORKSHOP  eastus      Microsoft.Compute/disks
MyFortiWebVM_OsDisk_1_6259c4a932fe4cfd866015e1fb611558  K8S51-K8S101-WORKSHOP  eastus      Microsoft.Compute/disks
```

{{% /tab %}}
{{% tab title="SSH to FWeb" %}}

- **Verify FortiWeb VM has been created and you have ssh access to it**

type `exit` to exit from SSH session 

```bash
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i $HOME/.ssh/$rsakeyname 
```
or directly append FortiWeb cli command 
```bash
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i $HOME/.ssh/$rsakeyname "get system status"
```
{{% /tab %}}
{{< /tabs >}}

#### 5. Create VNET Peering

Because AKS and FortiWeb are in different VNETs, they are isolated from each other.  We are going to use VNET Peering to connect FortiWeb VM with AKS workernode.  To do that, we need to get both vnetIds to create peering. 

{{< tabs title="VNet Peering" >}}
{{% tab title="VNet Ids" %}}

**define localPeer name and RemotePeer name **

```bash
localPeeringName="FortiWebToAksPeering"
remotePeeringName="AksToFortiWebPeering"
```

- **Get the full resource ID of the local VNet**

```bash
localVnetId=$(az network vnet show --resource-group $resourceGroupName --name $vnetName --query "id" -o tsv)
```

- **Get the full resource ID of the remote VNet**

```bash
remoteVnetId=$(az network vnet show  --resource-group $resourceGroupName --name $aksVnetName  --query "id" -o tsv)
echo $remoteVnetId
```
{{% /tab %}}
{{% tab title="Create Peering" %}}

- **Create peering from local VNet to remote VNet**

```bash
az network vnet peering create \
  --name $localPeeringName \
  --resource-group $resourceGroupName \
  --vnet-name $vnetName \
  --remote-vnet $remoteVnetId \
  --allow-vnet-access
```

- **Create peering from remote VNet to local VNet**

```bash
az network vnet peering create \
  --name $remotePeeringName \
  --resource-group $resourceGroupName \
  --vnet-name $aksVnetName \
  --remote-vnet $localVnetId \
  --allow-vnet-access
```

{{% /tab %}}
{{% tab title="Check status" %}}

- **Check vnet peering status**

```bash
az network vnet peering list -g $resourceGroupName --vnet-name AKS-VNET -o table
az network vnet peering list -g $resourceGroupName --vnet-name FortiWeb-VNET -o table
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}


You should see output like 

```
AllowForwardedTraffic    AllowGatewayTransit    AllowVirtualNetworkAccess    DoNotVerifyRemoteGateways    Name                  PeeringState    PeeringSyncLevel    ProvisioningState    ResourceGroup          ResourceGuid                          UseRemoteGateways
-----------------------  ---------------------  ---------------------------  ---------------------------  --------------------  --------------  ------------------  -------------------  ---------------------  ------------------------------------  -------------------
False                    False                  True                         False                        AksToFortiWebPeering  Connected       FullyInSync         Succeeded            k8s51-k8s101-workshop  e867030a-0101-00b2-19a0-fba24c2151dd  False
AllowForwardedTraffic    AllowGatewayTransit    AllowVirtualNetworkAccess    DoNotVerifyRemoteGateways    Name                  PeeringState    PeeringSyncLevel    ProvisioningState    ResourceGroup          ResourceGuid                          UseRemoteGateways
-----------------------  ---------------------  ---------------------------  ---------------------------  --------------------  --------------  ------------------  -------------------  ---------------------  ------------------------------------  -------------------
False                    False                  True                         False                        FortiWebToAksPeering  Connected       FullyInSync         Succeeded            k8s51-k8s101-workshop  e867030a-0101-00b2-19a0-fba24c2151dd  False
```
{{% /tab %}}
{{< /tabs >}}

#### 6. Verify the connectivity between FortiWeb VM and AKS 

{{< tabs title="Verify FortiWeb-AKS connectivity" >}}
{{% tab title="WorkerNode IP" %}}

- **get AKS worker node ip**

```bash
nodeIp=$(kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')
echo $nodeIp

```
{{% /tab %}}
{{% tab title="Verify" %}}

- **Verify the connectivity between FortiWeb VM and AKS worker node**
Use ping from FortiWeb VM to AKS node

```bash
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i ~/.ssh/$rsakeyname execute ping $nodeIp
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}

You will see output like 

```
MyFortiWebVM # PING 10.224.0.4 (10.224.0.4): 56 data bytes
64 bytes from 10.224.0.4: icmp_seq=1 ttl=64 time=2.5 ms
64 bytes from 10.224.0.4: icmp_seq=2 ttl=64 time=1.1 ms
64 bytes from 10.224.0.4: icmp_seq=3 ttl=64 time=1.2 ms
64 bytes from 10.224.0.4: icmp_seq=4 ttl=64 time=1.2 ms
64 bytes from 10.224.0.4: icmp_seq=5 ttl=64 time=15.0 ms
```
{{% /tab %}}
{{< /tabs >}}

#### 7. Config FortiWeb VM 

FortiWeb requires some basic configuration to work with ingress Controller 
config list:
1. enable HTTPS API access on TCP port 443
2. enable traffic log
3. config static route
- static route to AKS vnet subnet via Port1
- default route to internet via Port2 when use FortiWeb in twoarms mode
- static route to your client IP (your azure shell) via Port1 
  - This ensures your client session (your azure shell) can SSH into FortiWeb via Port1 public ip.

{{< tabs >}}
{{% tab title="clientIP" %}}
```bash
##get your azure shell client ip
myclientip=$(curl -s https://api.ipify.org)
echo $myclientip 

cat << EOF | tee > basiconfig.txt
config system global
  set admin-sport 443
end
config log traffic-log
  set status enable
end
EOF
cat << EOF | tee > interfaceport2config.txt
config system interface
  edit "port2"
    set type physical
    set allowaccess ping ssh snmp http https FWB-manager 
    set mode dhcp
  next
end
EOF

cat << EOF | tee > staticrouteconfigtwoarms.txt
config router static
  edit 10
    set dst 10.224.0.0/16
    set gateway 10.0.1.1
    set device port1
  next
  edit 2000
    set dst 0.0.0.0/0
    set gateway 10.0.2.1
    set device port2
  next
  edit 1000
    set dst $myclientip
    set gateway 10.0.1.1
    set device port1
  next
end
EOF

cat << EOF | tee > staticrouteconfigonearm.txt
config router static
  edit 10
    set dst 10.224.0.0/16
    set gateway 10.0.1.1
    set device port1
  next
EOF

ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name  -i  ~/.ssh/$rsakeyname < basiconfig.txt

if [ "$FortiWebdeploymode" == "twoarms" ]; then 
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name  -i  ~/.ssh/$rsakeyname < interfaceport2config.txt
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name  -i  ~/.ssh/$rsakeyname < staticrouteconfigtwoarms.txt
else 
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name  -i  ~/.ssh/$rsakeyname < staticrouteconfigonearm.txt
fi
{{% /tab %}}
{{% tab title="Verify Fweb config" %}}

```
- **Verify the FortiWeb Configuration**

you can ssh into FortiWeb to check configuration like static route etc., 
```bash
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name  -i  ~/.ssh/$rsakeyname show router static
```
{{% /tab %}}
{{< /tabs >}}

#### 8. SSH into FortiWeb via internal ip

You may lose connectivity to FortiWeb Public IP via SSH if your client ip subnet is not in FortiWeb static route config.  In this case, you can use FortiWeb internal IP for ssh.  We can create an ssh client pod to connect to FortiWeb via internal IP.
{{< tabs >}}
{{% tab title="Create pod" %}}
```bash

cat << EOF | tee sshclient.yaml 
apiVersion: v1
kind: Pod
metadata:
  name: ssh-jump-host
  labels:
    app: ssh-jump-host
spec:
  containers:
  - name: ssh-client
    image: alpine
    command: ["/bin/sh"]
    args: ["-c", "apk add --no-cache openssh && apk add --no-cache curl && tail -f /dev/null"]
    stdin: true
    tty: true
EOF

kubectl apply -f sshclient.yaml
```

{{% /tab %}}
{{% tab title="Connect" %}}

then

```bash
nic1privateip=$(az network nic show --name NIC1 -g $resourceGroupName  --query "ipConfigurations[0].privateIPAddress" --output tsv)
echo $nic1privateip
echo username $FortiWebUsername
echo password $FortiWebPassword
kubectl exec -it po/ssh-jump-host -- ssh $FortiWebUsername@$nic1privateip

```

{{% /tab %}}
{{< /tabs >}}

#### 9. Use Helm to deploy FortiWeb Ingress controller

- **What is Helm**

Helm is a package manager for Kubernetes that simplifies the deployment and management of applications within Kubernetes clusters. It uses charts, which are pre-configured packages of Kubernetes resources. Helm also uses Helm repositories, which are collections of charts that can be shared and accessed by others, facilitating the distribution and collaboration of Kubernetes applications. 
If you use the Azure Cloud Shell, the Helm CLI (Helm v3.6.3 or later ) is already installed. For installation instructions on your local platform, see Installing Helm https://helm.sh/docs/intro/install/ 

{{< tabs title="FWeb Ingress Controller">}}
{{% tab title="prep namespace" %}}

- **prepare namespace and releasename variable**

```bash
FortiWebingresscontrollernamespace="FortiWebingress"
releasename="FortiWeb-ingress-controller/fwb-k8s-ctrl"
```

{{% /tab %}}
{{% tab title="Help Repo" %}}
- **Add Helm Repository for FortiWeb Ingress Controller**

```bash
helm repo add FortiWeb-ingress-controller https://fortinet.github.io/FortiWeb-ingress/

```
- **Update Helm Repositories**

```bash
helm repo update

```
{{% /tab %}}
{{% tab title="K8s namespace" %}}
- **Create Namespace in Kubernetes**

```
kubectl create namespace $FortiWebingresscontrollernamespace

```
{{% /tab %}}
{{% tab title="install" %}}
- **Install FortiWeb Ingress Controller using Helm**

```bash
helm install first-release $releasename --namespace $FortiWebingresscontrollernamespace
```

{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}

you shall see output like this
```
NAME: first-release
LAST DEPLOYED: Tue Jun 11 03:19:14 2024
NAMESPACE: FortiWebingress
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

{{% /tab %}}
{{% tab title="Check Manifest" %}}
- **Check the manifest that deployed by Helm**

```
helm get manifest first-release -n $FortiWebingresscontrollernamespace 
```
{{% /tab %}}
{{% tab title="Check resources" %}}
- **Check Resource Deployment Status**
```bash
kubectl rollout status deployment first-release-fwb-k8s-ctrl -n FortiWebingress
```
{{% /tab %}}
{{% tab title="Check Fweb startup log" %}}
- **Check FortiWeb Ingress controller startup log**

```bash
kubectl logs -n 50 -l app.kubernetes.io/name=fwb-k8s-ctrl -n $FortiWebingresscontrollernamespace
```
{{% /tab %}}
{{% tab title="Expected Ingress controller log" style="info" %}}


you are expected to see output like 

```
Stopping FortiWeb ingress controller
Starting FortiWeb ingress controller
time="2024-06-11T03:19:34Z" level=info msg="==Starting FortiWeb Ingress controller"
```

{{% /tab %}}
{{< /tabs >}}

 #### 10. Deploy Backend Application in AKS 
We will deploy two service and expose with ClusterIP SVC , service1 and service2

{{< tabs >}}
{{% tab title="Service1" %}}


- **deploy service1**
```bash
imageRepo="public.ecr.aws/t8s9q7q9/andy2024public"
cat << EOF | tee > service1.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sise
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sise
  template:
    metadata:
      labels:
        app: sise
    spec:
      containers:
      - name: sise
        image: $imageRepo:demogeminiclient0.5.0
        imagePullPolicy: Always
        env: 
          - name: PORT
            value: "9876"
          - name: GEMINI_API_KEY
            value: ""
---
kind: Service
apiVersion: v1
metadata:
  name: service1
  annotations:
    health-check-ctrl: HLTHCK_ICMP
    lb-algo: round-robin
spec:
  type: NodePort
  ports:
  - port: 1241
    protocol: TCP
    targetPort: 9876
  selector:
    app: sise
  sessionAffinity: None

EOF
kubectl apply -f service1.yaml
kubectl rollout status deployment sise
```
{{% /tab %}}
{{% tab title="Service2" %}}

- **deploy service2**
```bash
imageRepo="public.ecr.aws/t8s9q7q9/andy2024public"
cat << EOF | tee > service2.yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: goweb
spec:
  replicas: 1
  selector:
    matchLabels:
      app: goweb
  template:
    metadata:
      labels:
        app: goweb
    spec:
      containers:
      - name: goweb
        image: $imageRepo:demogeminiclient0.5.0
        imagePullPolicy: Always
        env: 
          - name: PORT
            value: "9876"
---
kind: Service
apiVersion: v1
metadata:
  name: service2
  annotations:
    health-check-ctrl: HLTHCK_ICMP
    lb-algo: round-robin
spec:
  type: NodePort
  ports:
  - port: 1242
    protocol: TCP
    targetPort: 9876
  selector:
    app: goweb
  sessionAffinity: None
EOF
kubectl apply -f service2.yaml
kubectl rollout status deployment goweb
```
{{% /tab %}}
{{% tab title="Verify" %}}
- **Verify service**
```bash
kubectl get ep service1
kubectl get ep service2
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}
you shall see output like 

```
NAME       ENDPOINTS          AGE
service1   10.224.0.22:9876   14s
NAME       ENDPOINTS          AGE
service2   10.224.0.19:9876   6s
```
{{% /tab %}}
{{< /tabs >}}

 #### 11. Create ingress rule with yaml file 


FortiWeb ingress controller is the default ingress controller, it will read and parse the ingress rule. the ingress controller will also read annotation from yaml file for some configuration parameters like FortiWeb login ip and secrets etc., 
We will tell FortiWeb ingress controller use FortiWeb port1 ip for API access, and create VIP on FortiWeb Port2, the VIP address is on same subnet with Port2 with last octet set to .100.

Use the script below to get FortiWeb Port1 and Port2 IP address , then create yaml file with these IP address

{{< tabs >}}
{{% tab title="FWeb IP address" %}}
```bash
output=$(ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i ~/.ssh/$rsakeyname 'get system interface')
port1ip=$(echo "$output" | grep -A 7 "== \[ port1 \]" | grep "ip:" | awk '{print $2}' | cut -d'/' -f1)
if [ "$FortiWebdeploymode" == "twoarms" ]; then
port2ip=$(echo "$output" | grep -A 7 "== \[ port2 \]" | grep "ip:" | awk '{print $2}' | cut -d'/' -f1)
echo port2ip=$port2ip
vip=$(echo "$port2ip" | cut -d'.' -f1-3).100
else 
vip=$(echo "$port1ip" | cut -d'.' -f1-3).100
fi
echo port1ip=$port1ip
echo vip=$vip

```
{{% /tab %}}
{{% tab title="Secret" %}}
- **Create secret for FortiWeb API access**

the FortiWeb Ingress controller require username and password to access FortiWeb VM, therefore, we need to create a secret for FortiWeb Ingress controller, the secret save username/password in base64 encoded strings which is more secure then plain text. 

```bash
kubectl create secret generic fwb-login1 --from-literal=username=$FortiWebUsername --from-literal=password=$FortiWebPassword
```
{{% /tab %}}
{{% tab title="Ingress YAML" %}}
- **Create ingress yaml file**

Ingress Controller will read ingress object, then use the annotations to config FortiWeb use API.
"fwb-login1" is the secret that keep FortiWeb VM username and password
"virtual-server-ip" is the VIP to be configured on FortiWeb 
In spec, we also define a rules with host set to port2 public ip dns name.
if request url is /generate, the traffic will be redirect to service1
if request url is /info , the traffic will be redirect to service2

```bash
if [ "$FortiWebdeploymode" == "twoarms" ]; then
vipport="port2"
else
vipport="port1"
fi
cat << EOF | tee > 04_minimal-ingress.yaml 
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: m
  annotations: {
    "FortiWeb-ip" : $port1ip,    
    "FortiWeb-login" : "fwb-login1",  
    "FortiWeb-ctrl-log" : "enable",
    "virtual-server-ip" : $vip,
    "virtual-server-addr-type" : "ipv4",
    "virtual-server-interface" :$vipport, 
    "server-policy-web-protection-profile" : "Inline Standard Protection",
    "server-policy-https-service" : "HTTPS",
    "server-policy-http-service" : "HTTP",
    "server-policy-syn-cookie" : "enable",
    "server-policy-http-to-https" : "disable"
  }
spec:
  ingressClassName: fwb-ingress-controller
  rules:
  - host: $FortiWebvmdnslabelport2
    http:
      paths:
      - path: /generate
        pathType: Prefix
        backend:
          service:
            name: service1
            port:
              number: 1241
      - path: /info
        pathType: Prefix
        backend:
          service:
            name: service2
            port:
              number: 1242
EOF

```

{{% /tab %}}
{{% tab title="Deploy yamlfile" %}}

Now you have `04_minimal-ingress.yaml` file created. 
you can go ahead to deploy this yaml file directly, but if you want monitor the activities of FortiWeb Ingress Controller after apply this yaml file, you can do 

```bash
kubectl logs -f  -l app.kubernetes.io/name=fwb-k8s-ctrl -n FortiWebingress &  

kubectl apply -f 04_minimal-ingress.yaml
```
{{% /tab %}}
{{< /tabs >}}

#### 12. FortiWeb Configuration

You will see now FortiWeb has configured a few thingss.

{{< tabs title="Fweb config">}}
{{% tab title="VIP" %}}
1. VIP config on Port2

```bash
 ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i ~/.ssh/$rsakeyname 'get system vip'
```
{{% /tab %}}
{{% tab title="Policy policy" %}}

2. Server-policy policy

```bash
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i ~/.ssh/$rsakeyname show server-policy policy 
```

{{% /tab %}}
{{% tab title="Vserver policy" %}}
3. Server Policy Vserver
```bash
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i ~/.ssh/$rsakeyname  show server-policy vserver 
```
{{% /tab %}}
{{% tab title="Server pool" %}}
4. server-policy server pool

```bash
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i ~/.ssh/$rsakeyname  show server-policy server-pool
```
{{% /tab %}}
{{% tab title="Content-routing" %}}
5. server-policy http-content-routing-policy
```bash
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i ~/.ssh/$rsakeyname  show server-policy http-content-routing-policy
```
{{% /tab %}}
{{< /tabs >}}

#### 13. Verify ingress rule

{{< tabs title="Verify ingress">}}
{{% tab title="get rule" %}}
Verify the ingress rule created on k8s
```bash
kubectl get ingress
```
{{% /tab %}}
{{% tab title="Create test pod" %}}

Create test pod 
```bash
cat << EOF | tee > clientpod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: clientpod
  labels: 
    app: clientpod
spec:
  containers:
  - name: clientpod
    image: praqma/network-multitool
EOF
kubectl apply -f clientpod.yaml
```
{{% /tab %}}
{{% tab title="Verify NodePort" %}}

Verify nodePort svc

Since FortiWeb VM is outside of cluster, FortiWeb will use AKS nodePort to reach backend application.  Therefore the backend application has exposed via NodePort Svc , the client pod shall able to reach backend application via nodePort. So does FortiWeb VM. 


```bash
nodePort=$(kubectl get svc service1 -o jsonpath='{.spec.ports[0].nodePort}')
kubectl exec -it po/clientpod -- curl  http://$nodeIp:$nodePort/info 
```
and

```bash
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i $HOME/.ssh/$rsakeyname execute curl http://$nodeIp:$nodePort/info
```
{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}
You will see output like 
```
MyFortiWebVM #   % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0*   Trying 10.224.0.10:30890...
* Connected to 10.224.0.10 (10.224.0.10) port 30890
> GET /info HTTP/1.1
> Host: 10.224.0.10:30890
> User-Agent: curl/8.4.0
> Accept: */*
> 
< HTTP/1.1 200 OK
< Content-Type: application/json
< Date: Tue, 25 Jun 2024 01:59:56 GMT
< Content-Length: 20
< 
{ [20 bytes data]
100    20  100    20    0     0HTTP/1.1 200 OK
Content-Type: application/json
Date: Tue, 25 Jun 2024 01:59:56 GMT
Content-Length: 20

{"version":"0.6.0"}
   5333      0 --:--:-- --:--:-- --:--:--  6666
* Connection #0 to host 10.224.0.10 left intact
```
{{% /tab %}}
{{< /tabs >}}

#### 14. Create secondary ip and associate with public ip


This is to create an IP to use as VIP on FortiWeb and associate with a public ip for external access,  when run FortiWeb with twoarms mode the secondary ip is on NIC2 , when in onearm mode, the secondary ip is on NIC1. 
 
{{< tabs >}}
{{% tab title="NIC1" %}}
```bash
if [ "$FortiWebdeploymode" == "twoarms" ]; then
vipnicname="NIC2"
else        
vipnicname="NIC1"  
fi  
az network public-ip create \
  --resource-group $resourceGroupName \
  --name FWBPublicIPPort2 \
  --allocation-method Static \
  --sku Standard \
  --dns-name $FortiWebvmdnslabelport2


# Add a secondary IP configuration to NIC2
az network nic ip-config create \
  --resource-group $resourceGroupName \
  --nic-name $vipnicname \
  --name ipconfigSecondary \
  --private-ip-address $secondaryIp \
  --public-ip-address FWBPublicIPPort2
```  
{{% /tab %}}
{{% tab title="Verify" %}}
- **Verify the secondary IP address**
```bash
az network nic show \
  --resource-group $resourceGroupName \
  --name $vipnicname \
  --query "ipConfigurations[]" \
  --output table
``` 

{{% /tab %}}
{{% tab title="Expected Output" style="info" %}}
You will see output like 

in twoarms mode
```
Name               Primary    PrivateIPAddress    PrivateIPAddressVersion    PrivateIPAllocationMethod    ProvisioningState    ResourceGroup
-----------------  ---------  ------------------  -------------------------  ---------------------------  -------------------  ---------------------
ipconfig1          True       10.0.2.4            IPv4                       Dynamic                      Succeeded            k8s51-k8s101-workshop
ipconfigSecondary  False      10.0.2.100          IPv4                       Static                       Succeeded            k8s51-k8s101-workshop

```
in onearm mode
```
Name               Primary    PrivateIPAddress    PrivateIPAddressVersion    PrivateIPAllocationMethod    ProvisioningState    ResourceGroup
-----------------  ---------  ------------------  -------------------------  ---------------------------  -------------------  ---------------------
ipconfig1          True       10.0.1.4            IPv4                       Dynamic                      Succeeded            k8s51-k8s101-workshop
ipconfigSecondary  False      10.0.1.100          IPv4                       Static                       Succeeded            k8s51-k8s101-workshop

```
{{% /tab %}}
{{< /tabs >}}

Verify connectivity to FortiWeb VIP
FortiWeb has VIP configured which it's an alias of NIC2 interface(in twoarms mode) or NIC1 (in onearm mode). from client pod, you shall able to ping it.


```bash
kubectl exec -it po/clientpod -- ping -c 5 $secondaryIp
```

Reach ingress rule via FortiWeb reverse proxy on VIP 

Because FortiWeb has configured with reverseProxy on VIP with ingress rule. client pod shall able to access url via FortiWeb.

We have add "Host: $svcdnsname" in HTTP request Host header, as this is required in the ingress rule definition. 
the target application is gemini AI client. so we can send request data with your "prompt".

```bash
kubectl exec -it po/clientpod -- curl -v -H "Host: $svcdnsname" http://$secondaryIp:80/generate  -H "Content-Type: application/json" -d '{"prompt": "hi"}' | grep "HTTP/1.1 200 OK"
```
you shall get the response from backend server like this , which indicate you do not have Token for use gemini yet.

Access ingress service via external public ip or dns name

```bash
kubectl exec -it po/clientpod -- curl http://$svcdnsname/info 
```

 #### 15. Clean up: 

 {{% notice warning %}} Only run this step if you want to start over the deployment, if not please continue to next section. {{% /notice %}}

- **delete all resource**

if you want startover again, you can delete all resource then redo the installation 

```bash
resources=$(az resource list -g $resourceGroupName --query "[].{name:name, type:type}" -o tsv)
az resource list -g $resourceGroupName -o table
echo delete aks cluster
az aks delete --name $aksClusterName -g $resourceGroupName 
echo delete FortiWeb vm 
az vm delete --name MyFortiWebVM -g $resourceGroupName
echo delete nic 
az network nic delete --name NIC1 -g $resourceGroupName 
az network nic delete --name NIC2 -g $resourceGroupName 

echo delete public ip 
az network public-ip delete --name FWBPublicIP -g $resourceGroupName
az network public-ip delete --name FWBPublicIPPort2 -g $resourceGroupName
echo delete FortiWebvm disk
disks=$(az disk list -g $resourceGroupName --query "[].name" -o tsv)
for disk in $disks; do
az disk delete --name $disk --resource-group $resourceGroupName 
done
echo delete NSG
az network nsg delete --name MyNSG --resource-group $resourceGroupName
echo delete vnet
az network vnet delete --name $vnetName -g $resourceGroupName
az network vnet delete --name $aksVnetName -g $resourceGroupName
az resource list  -g $resourceGroupName -o table 
rm ~/.kube/config
ssh-keygen -R $vm_name
```


