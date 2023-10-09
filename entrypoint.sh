#!/bin/bash

service nginx start
service dnsmasq start
service smbd start
tail -f /dev/null
