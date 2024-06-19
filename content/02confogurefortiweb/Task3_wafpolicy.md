---
title: "Security and WAF policies"
menuTitle: "WAF policy"
weight: 30
---

## Setting up basic security features and WAF policies

FortiWeb is a web application firewall (WAF) from Fortinet that offers comprehensive security features designed to protect web applications from various attacks and vulnerabilities. Here are some of the basic security features provided by FortiWeb:

1. Web Application Firewall (WAF)
FortiWeb provides strong protection against common web attacks and vulnerabilities such as SQL injection, cross-site scripting (XSS), and cross-site request forgery (CSRF), among others. It uses both signature-based and behavior-based detection methods to identify threats.

2. DDoS Protection
FortiWeb offers Distributed Denial of Service (DDoS) attack protection to help safeguard your applications from volumetric attacks that aim to overwhelm the system with traffic, rendering the application non-responsive.

3. OWASP Top 10 Protection
FortiWeb is designed to protect against the vulnerabilities listed in the OWASP Top 10, which are the most critical security risks to web applications. This includes injection flaws, broken authentication, sensitive data exposure, and more.

4. Bot Mitigation
FortiWeb includes features to detect and block malicious bots that can perform credential stuffing, scraping, and other automated attacks that can undermine the security and performance of your applications.

5. SSL/TLS Encryption
FortiWeb supports SSL/TLS encryption to secure data in transit between clients and servers. It also provides SSL offloading to help improve the performance of your web servers by handling the encryption and decryption processes.

6. API Protection
With increasing use of APIs in modern applications, FortiWeb provides specialized protections for API-based services, including JSON and XML protection. It ensures that APIs are not exploited to gain unauthorized access or to compromise data.

7. Advanced Threat Protection
FortiWeb integrates with FortiSandbox to offer advanced threat protection, allowing it to analyze files and web content in a safe and isolated environment to detect new malware and zero-day exploits.

8. Machine Learning Capabilities
FortiWeb uses machine learning to dynamically and automatically identify normal behavior and detect anomalies. This helps in protecting against sophisticated threats and reduces false positives without extensive manual intervention.

9. Rate Limiting
To prevent abuse and ensure service availability, FortiWeb allows administrators to set rate limits on incoming requests, thus protecting against brute force attacks and other abusive behaviors by limiting how often a user can repeat actions.

10. IP Reputation and Geo-IP Based Filtering
FortiWeb leverages IP reputation services and Geo-IP based filtering to block traffic from known malicious sources or specific geographic regions, adding an additional layer of security.

These features collectively provide robust protection for web applications, ensuring they remain secure from a wide range of cyber threats while maintaining performance and accessibility. FortiWeb's comprehensive security measures make it an effective solution for businesses looking to safeguard their online operations.

To enable protection policies on fortiweb here is the procedure: (This is just to understand how manually protection policy is created)

1. First we create Server pool to have the application servers in a backend pool. 

We need to create the Server object for Fortiweb to send the traffic to application server.

​		Navigate to Server Objects >> Server >> Server Pool >> Create new


2. Input information as shown below. Select the Server Balance option for Server Health check option to appear. Click OK.

![image-20220602174520445](image-20220602174520445.png)

 
3. Once click OK in the above step the greyed out Create new button should now appear to create the Server object.

![image-20220602174528782](image-20220602174528782.png)

4. Now enter the IP address of application server, port number the pool member/application server listens for connections. 

![image-20220602174538435](image-20220602174538435.png)

Click OK once you enter the information.

5. Now we will need to create the Virtual Server IP on which the Traffic destined for server pool member arrives. When FortiWeb receives traffic destined for a Virtual server it can then forward to its pool members. 

![image-20220602174547402](image-20220602174547402.png) 

6. Enter the name for the Virtual Server and click OK. You can now click Create New to create the VIP object. 

![image-20220602174554614](image-20220602174554614.png)

 
7. Virtual Server item can be an IP address of the interface or an IP other than the interface. In this case we will use the interface IP - Turn on the Radio button for “use interface IP”, a drop down with interfaces will appear. Select Port1 as the interface for this Virtual Server item and click OK.

![image-20220602174605954](image-20220602174605954.png)

8. The Virtual Server for the app will be using the IP address of the Port1 Interface. 

![image-20220602174621853](image-20220602174621853.png)


9. We will now create a custom protection profile which we will be using in the Server policy to protect the application Server. 

​		Navigate to Policy >> Web Protection Profile > click on Inline Standard protection >> Click Clone 

![image-20220602174631921](image-20220602174631921.png)

13. Create a custom Protection profile, you can give a name of your choice. 

![image-20220602174644900](image-20220602174644900.png) 

14. Now let’s create a Server policy. Input Name for the server policy, Select the Virtual Server, Server pool which we created in the earlier steps from the drop down. 

​	   For the HTTP Service, Click **create new**

![image-20220602174652731](image-20220602174652731.png)

15. Enter the port number the Virtual Server traffic will be reached on. Let’s keep this to 3000. **(Note: You can set up any port here or even can use HTTP/HTTPS. To make it easy for the rest of the lab use Port 3000)** 

![image-20220602174701454](image-20220602174701454.png)

 
16. Now let’s attach the protection profile you created in the earlier steps and click OK.

![image-20220602174708421](image-20220602174708421.png)

17. let’s Navigate to the browser and type the Public IP assigned to your FortiWeb instance to get to the web browser.

​	   http://FortiWebIP:3000 

​	  For example: http://157.56.182.90:3000

![image-20220602174715897](image-20220602174715897.png)



