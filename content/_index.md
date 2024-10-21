---
title: "Fortinet XPerts 2024"
weight: 1
archetype: home
description : "Fortinet K8S 202 Workshop"
---

{{< Xperts24Banner line1="K8s 202:" line2="Container FortiOS (cFOS)" line3="FortiWeb Ingress Security" >}}

### Welcome to K8s 202 Workshop

**Usecase/Goal of this lab:**

Company ABC has Kubernetes workloads running in Azure Kubernetes Service (AKS) and is looking to enhance their security posture by integrating FortiWeb, a web application firewall (WAF). Given the highly ephemeral nature of Kubernetes environments, they require a solution that ensures automatic updates from the Kubernetes cluster to FortiWeb, maintaining real-time protection.

To achieve this, Company ABC plans to implement the FortiWeb Kubernetes Ingress Controller. This controller will facilitate seamless communication between the Kubernetes cluster and the FortiWeb WAF deployed in Azure, ensuring that any changes within the Kubernetes environment are promptly reflected in the WAF’s configuration. This setup will help protect their applications while maintaining the agility and scalability provided by Kubernetes.

Learning Objectives:

- Deploy AKS cluster
- Deploy FortiWeb VM in Azure
- Learn about Routing, Load balancing, Types of Ingress
- Install and Setup Ingress controller 
- Set up Web application protection polcy to do TLS based Ingress on FortiWeb
- Generate Attack and Set up URL rewriting on FortiWeb
- Troubleshooting tips 

**Lab Architecture**

1. One Arm mode North South inspection

 ![onearm](./images/FWEB%20k8s%20diagrams-onearm.png)

 2. Two Arm mode North South Inspection

 ![onearm](./images/FWEB%20k8s%20diagrams%20-%20twoarm.png)















