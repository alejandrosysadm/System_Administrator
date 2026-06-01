#!/bin/bash
for host in $(cat hosts.txt); do
    ping -c 2 $host &> /dev/null && echo "$host OK" || echo "$host FALLA"
done
