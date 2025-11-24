#!/bin/bash
grep "error" /var/log/apache2/error.log > ~/apache_errors_$(date +%F).log
