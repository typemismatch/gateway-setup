#!/bin/sh

cd /home/aws/gateway-setup/agent/device_startup
npm install

cd ..
cd lib-systemd-system
systemctl enable /home/aws/gateway-setup/agent/lib-systemd-system/nuc-device-register-lite.service
systemctl start nuc-device-register-lite.service
