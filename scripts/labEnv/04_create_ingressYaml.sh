#!/bin/bash -x 
location="westus"
vm_name="fortiwebvm7.$location.cloudapp.azure.com"
echo vm_name=$vm_name

ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${vm_name}" 
output=$(ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name 'get system interface')
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
config router static
  edit 10
    set dst 10.224.0.0/16
    set gateway 10.0.1.1
    set device port1
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

ssh -o "StrictHostKeyChecking=no" azureuser@fortiwebvm7.westus.cloudapp.azure.com <userdata.txt 

cat << EOF | tee > 05_minimal-ingress.yaml 
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minimal-ingress
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
  - host: test.com
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

kubectl apply -f 05_minimal-ingress.yaml
kubectl logs -l app.kubernetes.io/name=fwb-k8s-ctrl -n fortiwebingress
