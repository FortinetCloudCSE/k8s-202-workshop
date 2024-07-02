---
title: "routing and load balancing"
menuTitle: "Routing and Load balancing"
weight: 10
---

### Basic configuration settings for routing and load balancing

FortiWeb is Fortinet’s web application firewall (WAF) that provides protection against web-based threats and allows for the management of web traffic. Here’s a basic overview on how to configure routing and load balancing on FortiWeb:

### Routing Configuration

Static routes direct traffic exiting the FortiWeb appliance based upon the packet’s destination—you can specify through which network interface a packet leaves and the IP address of a next-hop router that is reachable from that network interface. 

Routers are aware of which IP addresses are reachable through various network pathways and can forward those packets along pathways capable of reaching the packets’ ultimate destinations. Your FortiWeb itself does not need to know the full route, as long as the routers can pass along the packet. 

You must configure FortiWeb with at least one static route that points to a router, often a router that is the gateway to the Internet or intrinsic router of Azure if its public cloud hosted VM.  You may need to configure multiple static routes if you have multiple gateway routers (e.g. each of which should receive packets destined for a different subset of IP addresses), redundant routers (e.g. redundant Internet/ISP links), or other special routing cases.

However, often you will only need to configure one route: a default route.

For example, if a web server is directly attached to one physical port on the FortiWeb, but all other destinations, such as connecting clients, are located in different VNETS in Azure, you might need to add a route to the destination vnet with the gateway IP of Port you would like to use. In this lab's case it will be the Azure intrinsic gateway IP of Port1. 


### Loadbalancing:

Fortiweb supports multiple load balancing algortihms. 

- Round Robin—Distributes new TCP connections to the next pool member, regardless of weight, response time, traffic load, or number of existing connections. FortiWeb avoids unresponsive servers.

Suppose you have three servers in your pool: Server1, Server2, and Server3. New TCP connections are distributed in the following order: Server1, then Server2, then Server3, and it repeats in this cycle.

- Weighted Round Robin—Distributes new TCP connections using the round-robin method, except that members with a higher weight value receive a larger percentage of connections.

If Server1 has a weight of 3, Server2 a weight of 1, and Server3 a weight of 2, the distribution of connections might look like: Server1, Server1, Server1, Server2, Server3, Server3, and then it repeats. Server1 gets more connections due to its higher weight.


- Least Connection: Distributes new TCP connections to the member with the fewest number of existing, fully-formed TCP connections. If there are multiple servers with the same least number of connections, FortiWeb will take turns and avoid always selecting the same member to distribute new connections.

If Server1 has 10 connections, Server2 has 5 connections, and Server3 has 5 connections, the next new connection will be sent to either Server2 or Server3, whichever has fewer active connections.

- URI Hash—Distributes new TCP connections using a hash algorithm based on the URI found in the HTTP header, excluding hostname.

A hash function is applied to the URI in the HTTP header (excluding the hostname). Suppose the URI "/api/data" consistently hashes to Server1, then all requests to "/api/data" will always be directed to Server1.


- Full URI Hash: Distributes new TCP connections using a hash algorithm based on the full URI string found in the HTTP header. The full URI string includes the hostname and path.

Similar to URI Hash, but the hash function is applied to the entire URI, including the hostname. For instance, requests to "http://example.com/api/data" might hash to Server2.

- Host Hash: Distributes new TCP connections using a hash algorithm based on the hostname in the HTTP Request header Host field.

This method applies a hash to the hostname found in the HTTP request's Host field. If requests come with "host1.example.com", and the hash points to Server3, all requests to "host1.example.com" will be directed to Server3.

- Host Domain Hash:Distributes new TCP connections using a hash algorithm based on the domain name in the HTTP Request header Host field.

A hash function is applied to the domain name in the Host field. For example, requests to any subdomain of "example.com" might consistently hash to Server1 based on the domain name.

- Source IP Hash: Distributes new TCP connections using a hash algorithm based on the source IP address of the request.

A hash function is applied to the source IP address of incoming requests. If the IP address 192.168.1.100 hashes to Server2, all requests from this IP will be directed to Server2.


- Least Response Time: Distributes incoming traffic to the back-end servers by multiplying average response time by the number of concurrent connections. Servers with the lowest value will get the traffic. In this way the client can connect to the most efficient back-end server.

Suppose the average response times are 20 ms for Server1, 30 ms for Server2, and 15 ms for Server3, with all having similar connection numbers. The next connection will be directed to Server3 due to its lowest response time.

- Probabilistic Weighted Least Response Time: For the Least Response Time, in extreme cases there might be a server consistently has relatively low response time compared to others, which causes most of traffic to be distributed to one server. As a solution to this case, Probabilistic Weighted Least Response Time distributes traffic based on least response time as well as probabilities. The least response time server is most likely to receive traffic, while the rest servers still have chance to process some of the traffic.

Using the previous example, if Server3 begins to receive a disproportionate amount of traffic, reducing its performance, this method might adjust probabilities such that Server1 and Server2 start to receive more connections to balance the load, even though Server3 still has the best average response time.