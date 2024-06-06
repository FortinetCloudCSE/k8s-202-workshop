#!/bin/bash -x

cat << EOF | tee > siseNodePortSvc.yaml
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
kubectl apply -f demogeminiclient.yaml
kubectl rollout status deployment sise

kubectl apply -f siseNodePortSvc.yaml

kubectl get ep service1
