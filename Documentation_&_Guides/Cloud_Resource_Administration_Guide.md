Overview:
Best practices for managing resources across Azure, AWS, and GCP.

Azure:
•	- List VMs: Get-AzVM
•	- Start/Stop VM: Start-AzVM, Stop-AzVM

AWS:
•	- List EC2 instances: aws ec2 describe-instances
•	- Start/Stop instance: aws ec2 start-instances --instance-ids i-xxxxxx

GCP:
•	- List Compute Engine instances: gcloud compute instances list
•	- Start/Stop VM: gcloud compute instances start|stop instance-name
