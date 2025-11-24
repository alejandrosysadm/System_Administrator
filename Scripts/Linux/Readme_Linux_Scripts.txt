# Linux – Bash Scripts

## Description
This repository contains **useful Bash scripts for Linux system administrators**, including monitoring, backups, user management, and log analysis.  
The scripts are designed to run on Linux, macOS, or Windows with WSL.

---

## Available Scripts

| Script | Description |
|--------|------------|
| Analyze_Apache_Logs.sh | Searches Apache logs for errors and exports them to a report file. |
| Directorys_Backups.sh | Performs backups of specified directories to another location. |
| Massive_Ping.sh | Pings multiple hosts and generates an availability summary. |
| Monitoring_CPU_Memory.sh | Monitors CPU and memory usage and prints it to the console. |
| Report_Disk_Space.sh | Generates a disk space report and saves it to a file. |
| Users_Manager.sh | Allows creating, listing, or deleting Linux users. |

---

## Dependencies

- Bash (Linux, macOS, or WSL on Windows)  
- Python 3 (optional for more complex analysis scripts)  
- Proper permissions to create users or access directories  
- Azure CLI (only if integrating Azure scripts)  

---

## Usage

1. Make the script executable (first time only):
```bash
chmod +x ScriptName.sh
