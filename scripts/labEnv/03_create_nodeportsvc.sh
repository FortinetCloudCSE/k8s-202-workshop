#!/bin/bash -x

kubectl apply -f demogeminiclient.yaml
kubectl apply -f goweb.yaml
kubectl rollout status deployment sise
kubectl rollout status deployment goweb
kubectl get ep service1
kubectl get ep service2
