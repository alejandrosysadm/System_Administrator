#!/bin/bash
echo "CPU usage:"
top -bn1 | grep "Cpu(s)"
echo "Memory usage:"
free -h
