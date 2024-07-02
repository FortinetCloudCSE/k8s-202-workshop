#!/bin/bash -xe
./01_Create_Azure_VM_New_VNET.sh && 
./01_5_sshfortiweb.sh && 
./02_install_ingress_controller.sh && 
./03_create_nodeportsvc.sh  
sleep 5
./04_create_ingressYaml.sh && 
./05_updateNIC2ip.sh  &&
./06_verify.sh
if [ $? -ne 0 ]; then
  echo "something failed"
  exit 1
fi
