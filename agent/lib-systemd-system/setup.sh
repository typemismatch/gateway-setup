#!/bin/sh

cd /home/aws/gateway-setup/agent/device_startup
npm install

cd ..
cd lib-systemd-system
systemctl enable nuc-device-register-lite.service
systemctl start nuc-device-register-lite.service
