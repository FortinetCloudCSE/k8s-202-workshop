#!/bin/bash -x
location="westus"
fortiwebvmdnslabel="$(whoami)fortiwebvm7"
echo $fortiwebvmdnslabel
vm_name="$fortiwebvmdnslabel.$location.cloudapp.azure.com"
fortiwebvmdnslabelport2="$(whoami)px2.$location.cloudapp.azure.com"
echo $fortiwebvmdnslabelport2
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=US/ST=California/L=Sunnyvale/O=GlobalSecurity/OU=Dev/CN=$fortiwebvmdnslabelport2" \
    -keyout cert.key  -out cert.crt
