#!/bin/bash -x

cat << EOF | tee > siseNodePortSvc.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sise
  labels:
    app: sise
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sise
  template:
    metadata:
      labels:
        app: sise
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
  annotations:
    health-check-ctrl: HLTHCK_ICMP
    lb-algo: round-robin
spec:
  type: NodePort
  ports:
  - port: 1241
    protocol: TCP
    targetPort: 9876
  selector:
    app: sise
  sessionAffinity: None
EOF
kubectl apply -f siseNodePortSvc.yaml

kubectl rollout status deployment sise
kubectl get ep service1
