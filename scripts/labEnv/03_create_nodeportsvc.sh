#!/bin/bash -x

cat << EOF | tee > siseNodePortSvc.yaml
kind: Pod
apiVersion: v1
metadata:
  name: sise
  labels:
    run: sise
spec:
  containers:
  - name: sise
    image: mhausenblas/simpleservice:0.5.0
    ports:
    - containerPort: 9876
---
kind: Service
apiVersion: v1
metadata:
  name: service1
  annotations: {
    "health-check-ctrl" : "HLTHCK_ICMP",
    "lb-algo" : "round-robin",
  }
spec:
  type: NodePort
  ports:
  - port: 1241
    protocol: TCP
    targetPort: 9876
  selector:
    run: sise
  sessionAffinity: None
EOF
kubectl apply -f siseNodePortSvc.yaml

echo use kubectl get ep service1 to check service1 readiness
