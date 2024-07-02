#!/bin/bash -x 
location="westus"
fortiwebvmdnslabel="$(whoami)fortiwebvm7"
echo $fortiwebvmdnslabel
vm_name="$fortiwebvmdnslabel.$location.cloudapp.azure.com"
fortiwebvmdnslabelport2="$(whoami)px2.$location.cloudapp.azure.com"
echo $fortiwebvmdnslabelport2

echo vm_name=$vm_name
rsakeyname="id_rsa_tecworkshop"
ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${vm_name}" 
output=$(ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i ~/.ssh/$rsakeyname 'get system interface')
echo $output

port1ip=$(echo "$output" | grep -A 7 "== \[ port1 \]" | grep "ip:" | awk '{print $2}' | cut -d'/' -f1)
echo $port1ip
#port2ip=$(echo "$output" | grep -A 7 "== \[ port2 \]" | grep "ip:" | awk '{print $2}' | cut -d'/' -f1)
#echo $port2ip

port1ip_first3=$(echo "$port1ip" | cut -d'.' -f1-3)

cat << EOF | tee > userdata.txt
config system global
  set admin-sport 443
end
EOF

ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i ~/.ssh/$rsakeyname <userdata.txt 

if kubectl get svc service1 ; then 
cat << EOF | tee > 08_tls-ingress.yaml 
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: t
  annotations: {
    "fortiweb-ip" : $port1ip,    
    "fortiweb-login" : "fwb-login1",  
    "fortiweb-ctrl-log" : "enable",
    "virtual-server-ip" : $port1ip_first3.5, 
    "virtual-server-addr-type" : "ipv4",
    "virtual-server-interface" : "port1",
    "server-policy-web-protection-profile" : "Inline Standard Protection",
    "server-policy-https-service" : "HTTPS",
    "server-policy-http-service" : "HTTP",
    "server-policy-syn-cookie" : "enable",
    "server-policy-http-to-https" : "disable"
  }
spec:
  ingressClassName: fwb-ingress-controller
  tls:
  - hosts: 
     - $fortiwebvmdnslabelport2
    secretName: tls-secret
  rules:
  - host: $fortiwebvmdnslabelport2
    http:
      paths:
      - path: /info
        pathType: Prefix
        backend:
          service:
            name: service1
            port:
              number: 1241
 
EOF

kubectl apply -f 08_tls-ingress.yaml
kubectl get ingressclass && kubectl get ingress
kubectl logs -l app.kubernetes.io/name=fwb-k8s-ctrl -n fortiwebingress
else
echo PLEASE CREATE BACKEND SERVICE FIRST
exit 1
fi
