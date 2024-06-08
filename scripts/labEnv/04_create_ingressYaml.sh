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
port2ip=$(echo "$output" | grep -A 7 "== \[ port2 \]" | grep "ip:" | awk '{print $2}' | cut -d'/' -f1)
echo $port2ip

port2ip_first3=$(echo "$port2ip" | cut -d'.' -f1-3)

cat << EOF | tee > userdata.txt
config system global
  set admin-sport 443
end
config log traffic-log
  set status enable
end
config router static
  edit 10
    set dst 10.224.0.0/16
    set gateway 10.0.1.1
    set device port1
  next
  edit 100
    set dst 119.3.33.95/32
    set gateway 10.0.2.1
    set device port2
  next
  edit 101
    set dst 34.0.0.0/8
    set gateway 10.0.2.1
    set device port2
  next
end
config system interface
  edit "port2"
    set type physical
    set allowaccess ping ssh snmp http https FWB-manager 
    set mode dhcp
    config  secondaryip
    end
    config  classless_static_route
    end
  next
end
EOF

ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name -i ~/.ssh/$rsakeyname <userdata.txt 

if kubectl get svc service1 ; then 
cat << EOF | tee > 04_minimal-ingress.yaml 
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: m
  annotations: {
    "fortiweb-ip" : $port1ip,    
    "fortiweb-login" : "fwb-login1",  
    "fortiweb-ctrl-log" : "enable",
    "virtual-server-ip" : $port2ip_first3.100, 
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
EOF

kubectl apply -f 04_minimal-ingress.yaml
kubectl get ingressclass && kubectl get ingress
kubectl logs -l app.kubernetes.io/name=fwb-k8s-ctrl -n fortiwebingress
else
echo PLEASE CREATE BACKEND SERVICE FIRST
exit 1
fi
