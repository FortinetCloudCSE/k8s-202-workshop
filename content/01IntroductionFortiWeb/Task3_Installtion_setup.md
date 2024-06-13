---
title: "Installation prerequisites and setting up the FortiWeb Ingress Controller"
menuTitle: "Ch 3: Installation and Setup"
weight: 10
---

### Demo Diagram

### Prepare Environemnt 

#### Create Resource Group

```bash
location="westus"
owner="tecworkshop"
resourceGroupName=$owner-$(whoami)-"fortiweb-"$location-$(date +%Y-%m
)
az group create --name $resourceGroupName --location $location
```

check the result with 
```bash
az group show -g $resourceGroupName
```
you shall found "provisioningState": "Succeeded" from output

#### Create AKS clsuter 

We can use either managed K8s like AKS or self-managed k8s. 

```bash
rsakeyname="id_rsa_tecworkshop"
aksClusterName=$(whoami)-aks-cluster
[ ! -f ~/.ssh/$rsakeyname ] && ssh-keygen -t rsa -b 4096 -q -N "" -f ~/.ssh/$rsakeyname

az aks create \
    --name ${aksClusterName} \
    --node-count 1 \
    --vm-set-type VirtualMachineScaleSets \
    --network-plugin azure \
    --service-cidr  10.96.0.0/16 \
    --dns-service-ip 10.96.0.10 \
    --nodepool-name worker \
    --resource-group $resourceGroupName \
    --ssh-key-value ~/.ssh/${rsakeyname}.pub
az aks get-credentials -g  $resourceGroupName -n ${aksClusterName} --overwrite-existing
```
verify aks create with 

```
kubectl get node 
```
you shall found node are in "ready" status.


#### Create FortiWeb VNET
In this workshop, We deploy FortiWeb in it's own VNET, FortiWeb will require 
- VNET
- Subnet1: 10.0.1.0/24
- Subnet2: 10.0.2.0/24
- NSG : allow all traffic 
- NIC1 with Public IP for SSH access and Management, in Subnet1
- NIC2 for internal traffic, in Subnet2
- VM with Extra DISK for log

Create VNET with Subnet1
```bash
vnetName="FortiWeb-VNET"
az network vnet create \
  --resource-group $resourceGroupName \
  --name $vnetName \
  --address-prefix 10.0.0.0/16 \
  --subnet-name ExternalSubnet \
  --subnet-prefix 10.0.1.0/24
```
Create Subnet2
```bash
az network vnet subnet create \
  --resource-group $resourceGroupName \
  --vnet-name $vnetName \
  --name InternalSubnet \
  --address-prefix 10.0.2.0/24
```
Create NGS with Rule

```
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
```
Create PublicIP for NIC1
```bash
fortiwebvmdnslabel="$(whoami)fortiwebvm7"
az network public-ip create \
  --resource-group $resourceGroupName \
  --name FWBPublicIP \
  --allocation-method Static \
  --sku Standard \
  --dns-name $fortiwebvmdnslabel
```
Create NIC1 and attach PublicIP

```bash
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

```

Create NIC2 
```bash
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
```

#### Deploy FortiWeb VM 
Create VM
--data-disk-sizes-gb is required, otherwise, Fortiweb will not able to log any traffic.


```bash
imageName="fortinet:fortinet_fortiweb-vm_v5:fortinet_fw-vm:latest"
fortiwebUsername="azureuser"
fortiwebPassword='Welcome.123456!'
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
  --data-disk-sizes-gb 30 \
  --ssh-key-values @~/.ssh/${rsakeyname}.pub
```
you shall see output like this 

```
{
  "fqdns": "andyfortiwebvm7.westus.cloudapp.azure.com",
  "id": "/subscriptions/10d679ec-0db6-4d5e-ab03-cbc68d5dd8e3/resourceGroups/tecworkshop-andy-fortiweb-westus-2024-06/providers/Microsoft.Compute/virtualMachines/MyFortiWebVM",
  "location": "westus",
  "macAddress": "00-22-48-04-A0-56,00-22-48-04-AB-55",
  "powerState": "VM running",
  "privateIpAddress": "10.0.1.4,10.0.2.4",
  "publicIpAddress": "104.40.59.52",
  "resourceGroup": "tecworkshop-andy-fortiweb-westus-2024-06",
  "z
}
```
Verify Fortiweb VM has been created and you have ssh access to it.

```bash
ssh -o "StrictHostKeyChecking=no" azureuser@$(whoami)fortiwebvm7.westus.cloudapp.azure.com -i $HOME/.ssh/id_rsa_tecworkshop
```

#### Create VNET Peering
Because AKS and Fortiweb are in different VNET, a VNET Peering is required to make Fortiweb VM able to talk AKS workload. 

define localPeer name and RemotePeer name 
```bash
localPeeringName="FortiWebToAksPeering"
remotePeeringName="AksToFortiWebPeering"
remoteResourceGroup="MC"_${resourceGroupName}_${aksClusterName}_${location}
```

Get the full resource ID of the local VNet
```bash
localVnetId=$(az network vnet show --resource-group $resourceGroupName --name $vnetName --query "id" -o tsv)
```

Get the full resource ID of the remote VNet
```bash
remoteVnetName=$(az network vnet list  --resource-group $remoteResourceGroup --query "[0].name" -o tsv)
remoteVnetId=$(az network vnet show --resource-group $remoteResourceGroup --name $remoteVnetName --query "id" -o tsv)
echo "Remote VNet ID: $remoteVnetId"
```

Create peering from local VNet to remote VNet
```bash
az network vnet peering create \
  --name $localPeeringName \
  --resource-group $resourceGroupName \
  --vnet-name $vnetName \
  --remote-vnet $remoteVnetId \
  --allow-vnet-access
```

Create peering from remote VNet to local VNet
```bash
az network vnet peering create \
  --name $remotePeeringName \
  --resource-group $remoteResourceGroup \
  --vnet-name $remoteVnetName \
  --remote-vnet $localVnetId \
  --allow-vnet-access
```
##### Verify the connectivity between Fortiweb VM and AKS 

get AKS worker node ip 


```bash
nodeIp=$(kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')
echo $nodeIp

```
ping from Fortiweb VM to AKS node

```bash
ssh -o "StrictHostKeyChecking=no" azureuser@$fortiwebvmdnslabel.westus.cloudapp.azure.com -i ~/.ssh/$rsakeyname execute ping $nodeIp
```
you shall result like
```
MyFortiWebVM # PING 10.224.0.4 (10.224.0.4): 56 data bytes
64 bytes from 10.224.0.4: icmp_seq=1 ttl=64 time=2.5 ms
64 bytes from 10.224.0.4: icmp_seq=2 ttl=64 time=1.1 ms
64 bytes from 10.224.0.4: icmp_seq=3 ttl=64 time=1.2 ms
64 bytes from 10.224.0.4: icmp_seq=4 ttl=64 time=1.2 ms
64 bytes from 10.224.0.4: icmp_seq=5 ttl=64 time=15.0 ms
```

### Config Fortiweb 

Fortiweb require some basic configuration to work with ingress Controller 
config list:
1. enable HTTPS API access on TCP port 443
2. enable traffic log
3. config static route
3.1 static route to AKS vnet subnet via Port1
3.2 default route to internet via Port2 
3.3 static route to your client IP (your azure shell) via Port1 

```bash
location="westus"
fortiwebvmdnslabel="$(whoami)fortiwebvm7"
vm_name="$fortiwebvmdnslabel.$location.cloudapp.azure.com"
rsakeyname="id_rsa_tecworkshop"
myclientip=$(curl -s https://api.ipify.org)
echo $myclientip
cat << EOF | tee > basiconfig.txt
config system global
  set admin-sport 443
end
config log traffic-log
  set status enable
end
config system interface
  edit "port2"
    set type physical
    set allowaccess ping ssh snmp http https FWB-manager 
    set mode dhcp
  next
end
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
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name  -i  ~/.ssh/$rsakeyname < basiconfig.txt
```
Verify the Fortiweb Configuration

you can ssh into Fortiweb to check configuration like static route etc., 
```bash
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name  -i  ~/.ssh/$rsakeyname 
```

### Use Helm to deploy Fortiweb Ingress controller

#### What is Helm

### Deploy Fortiweb Ingress Controller

#### Create secret 

the FortiWeb Ingress controller require username and password to access FortiWeb VM, therefore, we need to create a secret for Fortiweb Ingress controller, the secret save username/password in base64 encoded strings which is more secure then plain text. 

```bash
kubectl create secret generic fwb-login1 --from-literal=username=$fortiwebUsername --from-literal=password=$fortiwebPassword
```

#### 
Set Namespace and Release Name Variables: 
```bash
fortiwebingresscontrollernamespace="fortiwebingress"
releasename="FortiWeb-ingress-controller/fwb-k8s-ctrl"
```
Add Helm Repository for FortiWeb Ingress Controller:
```bash
helm repo add FortiWeb-ingress-controller https://fortinet.github.io/fortiweb-ingress/

```
Update Helm Repositories:
```bash
helm repo update

```
Create Namespace in Kubernetes:
```
kubectl create namespace $fortiwebingresscontrollernamespace

```
Install FortiWeb Ingress Controller using Helm:
```bash
helm install first-release $releasename --namespace $fortiwebingresscontrollernamespace
```
you shall see output like this
```
NAME: first-release
LAST DEPLOYED: Tue Jun 11 03:19:14 2024
NAMESPACE: fortiwebingress
STATUS: deployed
REVISION: 1
TEST SUITE: None
```
Check Deployment Status:
```bash
kubectl rollout status deployment first-release-fwb-k8s-ctrl -n fortiwebingress
```
Check Fortiweb Ingress controller startup log

```bash
k logs -f -l app.kubernetes.io/name=fwb-k8s-ctrl -n $fortiwebingresscontrollernamespace
```
you shall see 
```
Stopping fortiweb ingress controller
Starting fortiweb ingress controller
time="2024-06-11T03:19:34Z" level=info msg="==Starting FortiWEB Ingress controller"
```

### Create backend demo service1 and service2

deploy backend application and expose with clusterIP svc service1
```bash
cat << EOF | tee > demogeminiclient.yaml
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
        image: interbeing/myfmg:demogeminiclient0.5.0
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
kubectl apply -f demogeminiclient.yaml
kubectl rollout status deployment sise
```
Verify the backend service with 
```bash
kubectl get ep service1
```
you shall see output like
```
NAME       ENDPOINTS          AGE
service1   10.224.0.21:9876   67s
```


deploy another backend application and expose with clusterIP svc service2
```bash
cat << EOF | tee > goweb.yaml
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
        image: interbeing/myfmg:demogeminiclient0.5.0
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
kubectl apply -f goweb.yaml
kubectl rollout status deployment goweb
```
Verify service with 
```bash
kubectl get ep service2
```
you shall see output like 

```
NAME       ENDPOINTS          AGE
service2   10.224.0.23:9876   8s
```

### Create minimal-ingress yaml file 

We will tell fortiweb ingress controller use fortiweb port1 ip for API access, and create VIP on Fortiweb Port2, the VIP address is on same subnet with Port2 with last octet set to .100.

use below script to get Fortiweb Port1 and Port2 IP address , then create yaml file with these IP address

```bash
output=$(ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i ~/.ssh/$rsakeyname 'get system interface')
port1ip=$(echo "$output" | grep -A 7 "== \[ port1 \]" | grep "ip:" | awk '{print $2}' | cut -d'/' -f1)
port2ip=$(echo "$output" | grep -A 7 "== \[ port2 \]" | grep "ip:" | awk '{print $2}' | cut -d'/' -f1)
vip=$(echo "$port2ip" | cut -d'.' -f1-3).100
echo $port1ip
echo $port2ip
echo $vip
```
Create ingress yaml file
Ingress Controller will read ingress object, then use the annotations to config Fortiweb use API.
"fwb-login1" is the secret that keep Fortiweb VM username and password
"virtual-server-ip" is the VIP to be configured on FortiWeb 
In spec, we also define a rules with host set to port2 public ip dns name.
if request url is /generate, the traffic will be redirect to service1
if request url is /info , the traffic will be redirect to service2

```bash
fortiwebvmdnslabelport2="$(whoami)px2.$location.cloudapp.azure.com" 
cat << EOF | tee > 04_minimal-ingress.yaml 
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: m
  annotations: {
    "fortiweb-ip" : $port1ip,    
    "fortiweb-login" : "fwb-login1",  
    "fortiweb-ctrl-log" : "enable",
    "virtual-server-ip" : $vip,
    "virtual-server-addr-type" : "ipv4",
    "virtual-server-interface" : "port2",
    "server-policy-web-protection-profile" : "Inline Standard Protection",
    "server-policy-https-service" : "HTTPS",
    "server-policy-http-service" : "HTTP",
    "server-policy-syn-cookie" : "enable",
    "server-policy-http-to-https" : "disable"
  }
spec:
  ingressClassName: fwb-ingress-controller
  rules:
  - host: $fortiwebvmdnslabelport2
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
now you have `04_minimal-ingress.yaml` file created. 
you can go ahead to deploy this yaml file directly, but if you want monitor the activites of Fortiweb Ingress Controller after apply this yaml file, you can do 

```bash
kubectl logs -f  -l app.kubernetes.io/name=fwb-k8s-ctrl -n fortiwebingress &  

kubectl apply -f 04_minimal-ingress.yaml
```

you shall see now Fortiweb has configured a few thing.

1. VIP config on Port2

```bash
 ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i ~/.ssh/$rsakeyname 'get system vip'
```
2. Server-policy policy

```bash
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i ~/.ssh/$rsakeyname show server-policy policy 
```
3. Server Policy Vserver
```bash
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i ~/.ssh/$rsakeyname  show server-policy vserver 
```
4. server-policy server pool

```bash
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i ~/.ssh/$rsakeyname  show server-policy server-pool
```
5. server-policy http-content-routing-policy
```bash
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i ~/.ssh/$rsakeyname  show server-policy http-content-routing-policy
```
