rsakeyname="id_rsa_tecworkshop"
location="westus"
fortiwebvmdnslabel="$(whoami)fortiwebvm7"
echo $fortiwebvmdnslabel
vm_name="$fortiwebvmdnslabel.$location.cloudapp.azure.com"
echo vm_name=$vm_name

ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${vm_name}"
ssh -o "StrictHostKeyChecking=no" azureuser@$vm_name  -i  ~/.ssh/$rsakeyname
