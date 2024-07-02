---
title: "K8s ingress types"
menuTitle: "K8s ingress"
weight: 20
---

Kubernetes Ingress is a vital component for managing access to applications running within a Kubernetes cluster from outside the cluster. It provides routing rules to manage external users' access to the services inside the cluster. Here’s a breakdown of different types of Kubernetes Ingress configurations:

1. Minimal Ingress
Minimal Ingress is the most straightforward type of Ingress. It's used primarily when you have a single service that needs to be exposed externally. The configuration directs all incoming traffic on the specified host to a single backend service.

Detailed Example:

```bash
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minimal-ingress
spec:
  defaultBackend:
    service:
      name: single-service
      port:
        number: 80
```
Explanation:

- This Ingress directs all traffic that does not match any other rule to the single-service at port 80.
- Useful for simple applications or initial development stages when complex routing rules are not needed.

2. Simple fanout:

A fanout configuration routes traffic to multiple services based on the URL path. for example, Used when hosting multiple services or APIs from the same IP address, directing users to different services based on the path.

```bash
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: simple-fanout
spec:
  rules:
  - host: fanout.example.com
    http:
      paths:
      - path: /blog
        pathType: Prefix
        backend:
          service:
            name: blog-service
            port:
              number: 80
      - path: /shop
        pathType: Prefix
        backend:
          service:
            name: shop-service
            port:
              number: 80
```
Explanation:

- Traffic to fanout.example.com/blog is directed to blog-service.
- Traffic to fanout.example.com/shop is directed to shop-service.
- Each service handles different parts of the application, allowing for modular and scalable design.


3. Ingress with Default backend 

This Ingress configuration includes both specific rules and a default backend to handle unmatched requests. for example,
To manage traffic to specific services while ensuring that all other requests are caught by a default backend.

```bash
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ingress-with-default-backend
spec:
  rules:
  - host: specific.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: specific-service
            port:
              number: 80
  defaultBackend:
    service:
      name: default-service
      port:
        number: 80
```

4. TLS/SSL Termination
This type of Ingress handles encrypted traffic, decrypting requests before passing them on to the appropriate services.

```bash
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tls-ingress
spec:
  tls:
  - hosts:
    - secure.example.com
    secretName: example-tls
  rules:
  - host: secure.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: secure-service
            port:
              number: 80
```

Explanation:

- Traffic to secure.example.com is handled with TLS, using the certificates stored in the Kubernetes secret example-tls.

5. ingress wildcard host

This configuration uses a wildcard host to match requests to any subdomain of a specified domain.

Typical Use Case:
Useful for organizations that have different environments for their app (like development, staging, and production) under different subdomains.


```bash
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: wildcard-host
spec:
  rules:
  - host: "*.example.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: wildcard-service
            port:
              number: 80
```
Explanation:
Requests to any subdomain of example.com are routed to wildcard-service


6. default backend
This Ingress configuration specifies a default backend. It is used when none of the rules in an Ingress resource match the incoming request.

Typical Use Case:
To catch all unmatched requests, providing a generic response, perhaps an error message or a redirect to the homepage.
Detailed YAML Example:

```bash
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: default-backend
spec:
  defaultBackend:
    service:
      name: default-service
      port:
        number: 80
```

Explanation:
All traffic that does not fit other specified rules is directed to default-service on port 80.
