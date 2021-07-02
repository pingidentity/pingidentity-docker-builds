#!/usr/bin/env sh
# Author: Arno
sudo tail -10 /var/log/secure | awk '$0~/Accepted publickey for ec2-user from/{ip=$11}END{print "You are calling from IP address [ \033[0;32m"ip"\033[0m ]"}'
