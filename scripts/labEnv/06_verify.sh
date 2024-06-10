#!/bin/bash -x 


rsakeyname="id_rsa_tecworkshop"
location="westus"
fortiwebvmdnslabel="$(whoami)fortiwebvm7"
owner="tecworkshop"
aksClusterName=$(whoami)-aks-cluster
echo $fortiwebvmdnslabel
vm_name="$fortiwebvmdnslabel.$location.cloudapp.azure.com"
svcdnsname="$(whoami)px2.$location.cloudapp.azure.com"
resourceGroupName=$owner-$(whoami)-"fortiweb-"$location-$(date -I)
remoteResourceGroup="MC"_${resourceGroupName}_${aksClusterName}_${location} 

#svcdnsname=${fortiwebvmdnslabel}port2.westus.cloudapp.azure.com 
#svcdnsname="test.com"

# Apply the toolpod configuration
kubectl apply -f toolpod.yaml
while true; do 
STATUS=$(kubectl get pod clientpod -o jsonpath='{.status.phase}')
  if [ "$STATUS" == "Running" ]; then
break
 else
 sleep 2
 continue
fi
done


echo "Checking pod to service node IP port"

# Get the NodePort for service1
nodePort=$(kubectl get svc service1 -o jsonpath='{.spec.ports[0].nodePort}')
if [ -z "$nodePort" ]; then
  echo "Failed to get NodePort for service1"
  exit 1
fi

echo nodePort=$nodePort

# Execute curl command inside the clientpod pod
kubectl exec -it po/clientpod -- curl -v http://10.224.0.4:$nodePort/info | grep "0.5.0"
if [ $? -ne 0 ]; then
  echo "Failed to curl service via NodePort"
  exit 1
fi
echo verify is succcessful 
sleep 2

echo "Checking pod to fortiweb VIP"

# Execute ping command inside the clientpod pod
kubectl exec -it po/clientpod -- ping -c 5 10.0.2.100
if [ $? -ne 0 ]; then
  echo "Ping to FortiWeb VIP failed. fortiweb VIP may not configured correctly."
  exit 1
fi
echo verify is succcessful 
sleep 2

echo "Checking pod to ingress via FortiWeb"

podegressip=$(az network public-ip list --resource-group $remoteResourceGroup  | jq -r .[0].ipAddress)
echo $podegressip 
echo below will test gemini api , make sure you have input the gemini API token as well as allow $podegressip has access to gemini API 

# Execute curl command with Host header inside the clientpod pod
kubectl exec -it po/clientpod -- curl -v -H "Host: $svcdnsname" http://10.0.2.100:80/generate  -H "Content-Type: application/json" -d '{"prompt": "hi"}' | grep "HTTP/1.1 200 OK"
if [ $? -ne 0 ]; then
  echo "Failed to curl ingress via FortiWeb"
  exit 1
fi


echo verify is succcessful 

echo "sending malicious traffic" 

kubectl exec -it po/clientpod -- curl -X POST -H "Content-Type: application/x-www-form-urlencoded" -d  '%{(#_='multipart/form-data').(#dm=@ognl.OgnlContext@DEFAULT_MEMBER_ACCESS).(#_memberAccess?(#_memberAccess=#dm):((#container=#context['com.opensymphony.xwork2.ActionContext.container']).(#ognlUtil=#container.getInstance(@com.opensymphony.xwork2.ognl.OgnlUtil@class)).(#ognlUtil.getExcludedPackageNames().clear()).(#ognlUtil.getExcludedClasses().clear()).(#context.setMemberAccess(#dm)))).(#cmd='bash').(#iswin=(@java.lang.System@getProperty('os.name').toLowerCase().contains('win'))).(#cmds=(#iswin?{'cmd.exe','/c',#cmd}:{'/bin/bash','-c',#cmd})).(#p=new java.lang.ProcessBuilder(#cmds)).(#p.redirectErrorStream(true)).(#process=#p.start()).(#ros=(@org.apache.struts2.ServletActionContext@getResponse().getOutputStream())).(@org.apache.commons.io.IOUtils@copy(#process.getInputStream(),#ros)).(#ros.flush())}' -H "Host: $svcdnsname" http://10.0.2.100:80/generate -H "Content-Type: application/json" -d '{"prompt": "hi"}'| grep "been blocked"

if [ $? -ne 0 ]; then
  echo "Failed to curl ingress via FortiWeb"
  exit 1
fi
echo traffic blocked by fortiweb sucessfully 

#echo "verify via public dns domain"

#kubectl exec -it po/clientpod -- curl -X POST -H "Content-Type: application/x-www-form-urlencoded" -d  '%{(#_='multipart/form-data').(#dm=@ognl.OgnlContext@DEFAULT_MEMBER_ACCESS).(#_memberAccess?(#_memberAccess=#dm):((#container=#context['com.opensymphony.xwork2.ActionContext.container']).(#ognlUtil=#container.getInstance(@com.opensymphony.xwork2.ognl.OgnlUtil@class)).(#ognlUtil.getExcludedPackageNames().clear()).(#ognlUtil.getExcludedClasses().clear()).(#context.setMemberAccess(#dm)))).(#cmd='bash').(#iswin=(@java.lang.System@getProperty('os.name').toLowerCase().contains('win'))).(#cmds=(#iswin?{'cmd.exe','/c',#cmd}:{'/bin/bash','-c',#cmd})).(#p=new java.lang.ProcessBuilder(#cmds)).(#p.redirectErrorStream(true)).(#process=#p.start()).(#ros=(@org.apache.struts2.ServletActionContext@getResponse().getOutputStream())).(@org.apache.commons.io.IOUtils@copy(#process.getInputStream(),#ros)).(#ros.flush())}' -H "Host: $svcdnsname" http://curl -v $svcdnsname:80/generate | grep "been blocked"

podegressip=$(az network public-ip list --resource-group $remoteResourceGroup  | jq -r .[0].ipAddress)
echo $podegressip

curl http://$svcdnsname/info 
curl http://ipx2.westus.cloudapp.azure.com/generate -H "Content-Type: application/json" -d '{"prompt": "your prompt here"}' 
echo "All checks completed successfully"
#in case you have lb with public ip point to fortiweb port2 
#ssh-keygen -f "${HOME}/.ssh/known_hosts" -R fwbmgmt.westus.cloudapp.azure.com
#echo ssh -o "StrictHostKeyChecking=no" azureuser@fwbmgmt.westus.cloudapp.azure.com -J root@$jumphost -i ~/.ssh/$rsakeyname 

echo ssh azureuser@ifortiwebvm7.westus.cloudapp.azure.com -i /Users/i/.ssh/id_rsa_tecworkshop
