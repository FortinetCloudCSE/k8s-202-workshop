---
title: "Fortinet TECWorkshop 202"
linkTitle: "Fortiweb workshop"
weight: 1
archetype: home
---

### Welcome to K8s 202 Workshop

**Usecase/Goal of this lab:**

Company ABC has Kubernetes workloads running in Azure Kubernetes Service (AKS) and is looking to enhance their security posture by integrating FortiWeb, a web application firewall (WAF). Given the highly ephemeral nature of Kubernetes environments, they require a solution that ensures automatic updates from the Kubernetes cluster to FortiWeb, maintaining real-time protection.

To achieve this, Company ABC plans to implement the FortiWeb Kubernetes Ingress Controller. This controller will facilitate seamless communication between the Kubernetes cluster and the FortiWeb WAF deployed in Azure, ensuring that any changes within the Kubernetes environment are promptly reflected in the WAF’s configuration. This setup will help protect their applications while maintaining the agility and scalability provided by Kubernetes.

Learning Objectives:

- Deploy AKS cluster
- Deploy FortiWeb VM in Azure
- Learn about Routing, Load balancing, Types of Ingress
- Install and Setup Ingress controller 
- Set up Web application protection polcy to do TLS based Ingress on Fortiweb
- Generate Attack and Set up URL rewriting on Fortiweb
- Troubleshooting tips 

**Lab Architecture**

1. One Arm mode North South inspection

 ![onearm](./images/FWEB%20k8s%20diagrams-onearm.png)

 2. Two Arm mode North South Inspection

 ![onearm](./images/FWEB%20k8s%20diagrams%20-%20twoarm.png)















