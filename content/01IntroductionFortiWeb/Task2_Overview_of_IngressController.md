---
title: "Introduction to Kubernetes Ingress Controllers and FortiWeb Integration"
menuTitle: "Ch 1: Introduction  to FortiWeb Ingress Controller"
weight: 10
---

### Overview of Ingress Controller

An **Ingress Controller** is a component in Kubernetes that manages the routing of external HTTP and HTTPS traffic to services within a Kubernetes cluster. It listens for Ingress resources created by users and configures the load balancer accordingly. Essentially, it acts as an entry point for external traffic, routing requests to the appropriate services based on the defined rules.

### Why Ingress Controller is Needed

1. **Centralized Traffic Management**: It centralizes the traffic management, allowing for easy routing rules setup.
2. **Load Balancing**: Distributes incoming traffic across multiple pods, ensuring high availability and reliability.
3. **SSL Termination**: Manages SSL/TLS termination, providing secure connections to the services.
4. **Path-Based Routing**: Allows for routing traffic to different services based on the request path.
5. **Name-Based Virtual Hosting**: Supports routing based on the hostname, enabling multiple applications to run on the same IP address.

### FortiWeb Ingress Controller Overview

The **FortiWeb Ingress Controller** fulfills Kubernetes Ingress resources and allows you to manage FortiWeb objects from Kubernetes. It is deployed in a container within a pod in a Kubernetes cluster.

The major functionalities of FortiWeb Ingress Controller include:

1. **List and Watch Ingress Resources**: Manages Ingress-related resources such as Ingress, Service, Node, and Secret.
2. **Convert Ingress Resources to FortiWeb Objects**: Converts resources to FortiWeb objects, such as virtual servers, content routing, real server pools, and more.
3. **Handle Events for Ingress Resources**: Automatically implements corresponding actions on FortiWeb for Add/Update/Delete events.

### Key Strengths of FortiWeb Ingress Controller

#### Integration of WAF and Ingress Controller Features

1. **Web Application Firewall (WAF) Capabilities**: Includes WAF capabilities, providing protection against common web vulnerabilities such as SQL injection, cross-site scripting (XSS), and other OWASP top 10 threats.
2. **Comprehensive Security**: Ensures that the traffic routed to the applications is secure, mitigating various web-based attacks at the ingress point itself.
3. **Multi-Layered Protection**: Uses multi-layered and correlated detection methods to defend applications from known vulnerabilities and zero-day threats.

#### Embedded Machine Learning (ML) Capabilities

1. **Adaptive Security**: The embedded ML capability allows FortiWeb to adapt and improve its threat detection over time. It can analyze traffic patterns and identify anomalies indicative of potential attacks.
2. **Zero-Day Threat Protection**: ML can detect and respond to zero-day threats by identifying suspicious behaviors that signify a new, previously unknown threat.
3. **Real-Time Threat Mitigation**: Offers real-time threat mitigation by continuously learning and adapting to new threat vectors, providing an extra layer of security for applications deployed in Kubernetes.

### Additional Features of FortiWeb Ingress Controller

1. **Health Check**: Ensures that the services are running correctly and efficiently.
2. **Traffic Log Management**: Manages and logs traffic for monitoring and analysis.
3. **FortiView**: Provides visibility into the traffic and security events, facilitating the management of Kubernetes ingress resources.

### Importance of ML in Addressing Zero-Day Threats

- **Proactive Defense**: ML-based systems can predict and identify new attack patterns that have not yet been cataloged in traditional databases.
- **Dynamic Adaptation**: Unlike static rule-based systems, ML systems evolve with the data they process, enhancing their capability to spot and mitigate new types of attacks.
- **Behavioral Analysis**: ML algorithms can analyze the behavior of users and traffic patterns to detect anomalies that could signify a zero-day threat.

In summary, the FortiWeb Ingress Controller's integration of WAF and ingress features, coupled with its embedded ML capabilities, provides a robust solution for securing Kubernetes applications. The ML capabilities are particularly crucial for detecting and mitigating zero-day threats, ensuring that applications remain protected against evolving security challenges.

### Deployment Models of Ingress Controllers

Most Ingress Controllers, such as NGINX or Kong, are deployed inside Kubernetes as a **Kubernetes Deployment**. They run in containers within the cluster, managing ingress traffic internally.

In contrast, the **FortiWeb Ingress Controller** operates differently. It is backed by a FortiWeb VM or physical appliance, with a light agent deployed in Kubernetes. This agent uses APIs to communicate with the external FortiWeb VM or appliance.

### Benefits of FortiWeb Ingress Controller

#### Benefits

1. **Enhanced Security**:
   - **Dedicated Hardware**: Using a physical appliance or VM provides dedicated resources for security operations, potentially enhancing performance and security.
   - **Advanced WAF Features**: FortiWeb appliances come with sophisticated Web Application Firewall capabilities that might surpass those available in container-based solutions.

2. **Resource Efficiency**:
   - **Offloading Workload**: By offloading security processing to an external appliance, it reduces the resource consumption within the Kubernetes cluster, freeing up resources for other workloads.

3. **Scalability**:
   - **Independent Scaling**: The FortiWeb appliance can be scaled independently of the Kubernetes cluster. This allows for flexible resource allocation based on traffic and security needs without affecting the cluster's performance.

