#!/bin/bash -x
fortiwebingresscontrollernamespace="fortiwebingress"
releasename="FortiWeb-ingress-controller/fwb-k8s-ctrl"
helm repo add FortiWeb-ingress-controller https://fortinet.github.io/fortiweb-ingress/
helm repo update
kubectl create namespace $fortiwebingresscontrollernamespace
helm install first-release  $releasename --namespace $fortiwebingresscontrollernamespace
kubectl get pod -n $fortiwebingresscontrollernamespace
