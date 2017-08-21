#!/bin/bash

echo -e "Cleaning up the NUC"

cd /home/aws
rm -fR .aws

#Delete everything except needed
shopt -s extglob
rm -v !("gateway-setup")
shopt -u extglob

#Cleanup node-red
rm /home/node-red/.node-red/*.json

#Cleanup greengrass
rm -fR /greengrass
rm -fR /greengrass/configuration/certs

#Copy back defaults
cp /home/aws/gateway-setup/conf_files/node-red/flows_ip.json /home/node-red/.node-red/flows_$HOSTNAME.json
cp /home/aws/gateway-setup/agent/device_startup/rootCA.pem /home/aws/rootCA.pem


