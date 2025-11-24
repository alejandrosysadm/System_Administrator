Overview:
Essential tasks for Linux server administration, including user management, package management, services, and file permissions.

User Management:
•	- Add user: sudo adduser username
•	- Delete user: sudo deluser username
•	- Add user to group: sudo usermod -aG groupname username

Package Management:
•	- Ubuntu/Debian: sudo apt update && sudo apt upgrade
•	- CentOS/RHEL: sudo yum update

Service Management:
•	- Check service status: systemctl status servicename
•	- Start/stop service: sudo systemctl start|stop servicename
•	- Enable service on boot: sudo systemctl enable servicename

File Permissions:
•	- Change owner: sudo chown user:group filename
•	- Change permissions: sudo chmod 755 filename
