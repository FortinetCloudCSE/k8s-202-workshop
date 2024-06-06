#!/bin/bash 
location="westus"
echo location= $location
owner="tecworkshop"
resourceGroupName=$owner-$(whoami)-"fortiweb-"$location-$(date -I)
az group delete -g $resourceGroupName
