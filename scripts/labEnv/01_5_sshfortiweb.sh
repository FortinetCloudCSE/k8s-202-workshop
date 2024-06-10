rsakeyname="id_rsa_tecworkshop"
location="westus"
fortiwebvmdnslabel="$(whoami)fortiwebvm7"
echo $fortiwebvmdnslabel
vm_name="$fortiwebvmdnslabel.$location.cloudapp.azure.com"
echo vm_name=$vm_name

ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${vm_name}"
export no_proxy=$no_proxy,api.ipify.org
echo $no_proxy
myclientip=$(curl -s https://api.ipify.org)
echo $myclientip
cat << EOF | tee > port2enablesshconfig.txt
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
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name  -i  ~/.ssh/$rsakeyname < port2enablesshconfig.txt
#ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name  -i  ~/.ssh/$rsakeyname 'show system interface'
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name  -i  ~/.ssh/$rsakeyname 'show route static'

