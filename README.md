# aggregator
For Getting started with aggregator use the setup.sh script

Add IP address of your proxy server in /opt/aggregator/servers.list
FOr users who are using loadbalancer or proxy server in a HA and needs a consolidated reports add #VIP_<VIRTUAL IP ADDRESS>

example servers.list
```
#list of IPs of SafeSquid Proxy Servers
10.200.1.115
10.200.1.116
#VIP_10.200.1.100
```
