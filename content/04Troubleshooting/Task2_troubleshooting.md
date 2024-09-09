---
title: "Troubleshooting"
linkTitle: "Troubleshooting"
chapter: false
weight: 20
---

#### Diagnosing Network Connectivity Issues

One of your first tests when configuring a new policy should be to determine whether allowed traffic is flowing to
your web servers.

1. Is there a server policy applied to the web server or servers FortiWeb was installed to protect? If it is
operating in Reverse Proxy mode, FortiWeb will not allow any traffic to reach a protected web server unless
there is a matching server policy that permits it.
2. If your network utilizes secure connections (HTTPS) and there is no traffic flow, is there a problem with your
certificate?

3. If you run a test attack from a browser aimed at your website, does it show up in the attack log?

To verify, configure FortiWeb to detect the attack, then craft a proof-of-concept that will trigger the attack sensor.

For example, to see whether directory traversal attacks are being logged and/or blocked, you could use your
web browser to go to:
http://www.example.com/login?user=../../../../
Under normal circumstances, you should see a new attack log entry in the attack log console widget of the
system dashboard.


4. use TCPDUMP equivalent command on FortiWeb **diagnose network sniffer <interface> <filter> 4 0 -a**

example: **diagnose network sniffer any "port 8443" 4 0  -a**

#### To ping a device from the FortiWeb CLI:

1. Log in to the CLI via either SSH, Telnet, or you can ping from the FortiWeb appliance in the CLI Console
accessed from the web UI.

2. If you want to adjust the behavior of execute ping, first use the execute ping options command.

3. Enter the command:

**execute ping <destination_ipv4>**
where <destination_ipv4> is the IP address of the device that you want to verify that the appliance can
connect to, such as 192.168.1.5. 

If the appliance can reach the host via ICMP, output similar to the following appears:

```bash
PING 192.0.2.96 (192.0.2.96): 56 data bytes
64 bytes from 192.0.2.96: icmp_seq=0 ttl=253 time=6.5 ms
64 bytes from 192.0.2.96: icmp_seq=1 ttl=253 time=7.4 ms
64 bytes from 192.0.2.96: icmp_seq=2 ttl=253 time=6.0 ms
64 bytes from 192.0.2.96: icmp_seq=3 ttl=253 time=5.5 ms
64 bytes from 192.0.2.96: icmp_seq=4 ttl=253 time=7.3 ms
--- 192.0.2.96 ping statistics ---
5 packets transmitted, 5 packets received, 0% packet loss
round-trip min/avg/max = 5.5/6.5/7.4 ms
EOF
```


If the appliance cannot reach the host via ICMP, output similar to the following appears:

```bash
PING 192.0.2.108 (192.0.2.108): 56 data bytes
Timeout ...
Timeout ...
Timeout ...
Timeout ...
Timeout ...
--- 192.0.2.108 ping statistics ---
5 packets transmitted, 0 packets received, 100% packet loss
EOF
```

“100% packet loss” and “Timeout” indicates that the host is not reachable.

#### For kubernetes ingress controller:

1. From the cluster check the ingress controller pod logs in namepsace to see if there are any errors.

```kubectl get pods -n FortiWebingress```

output:

```bash
NAME                                          READY   STATUS    RESTARTS   AGE
first-release-fwb-k8s-ctrl-59db65cddc-g4298   1/1     Running   0          2d15h
EOF
```

2. ```Kubectl logs first-release-fwb-k8s-ctrl-59db65cddc-g4298 -n FortiWebingress``` (Replace with your pod name and namespace)

output:

```bash

Do POST url https://10.0.1.4:443/api/v2.0/cmdb/server-policy/vserver/vip-list?mkey=default_m
default/m: Response status code: 500 URL https://10.0.1.4:443/api/v2.0/cmdb/server-policy/vserver/vip-list?mkey=default_m Resp {
        "results": {
                "errcode": -5,
                "message": "A duplicate entry has already existed."
        }
}
REQ BODY '{"data":{"status":"enable","use-interface-ip":"disable","vip":"default_m"}}'Do POST url https://10.0.1.4:443/api/v2.0/cmdb/server-policy/policy
default/m: Response status code: 500 URL https://10.0.1.4:443/api/v2.0/cmdb/server-policy/policy Resp {
        "results": {
                "errcode": -5,
                "message": "A duplicate entry has already existed."
        }
}
REQ BODY '{"data":{"case-sensitive":"disable","certificate":"","certificate-type":"disable","client-certificate-forwarding":"disable","client-certificate-forwarding-cert-header":"X-Client-Cert","
.
.
.
EOF
```