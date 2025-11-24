## Windows – PowerShell Scripts

| Script | Description |
|--------|------------|
| BackupScript.ps1 | Performs backups of important folders to a defined path. |

| Cleaner_Temporary_Files.ps1 | Cleans temporary files from Windows and the current user. |

| Disk_Space_Report.ps1 | Generates a CSV with used and free space for each disk. |

| Extract_Critical_System_Events_Viewer.ps1 | Extracts critical events from the Event Viewer into a CSV. |

| Show_AD_Users.ps1 | Lists Active Directory users and exports the information to a CSV. |

| Show_Azure_VMs.ps1 | Lists all Azure VMs and exports to a CSV. Requires the Az module. |

---

## Dependencies

- PowerShell 5.1 or higher  
- Az Module (only required for Azure scripts)  
- Proper permissions to run scripts and access AD or backup folders  

---

## Usage

Open PowerShell as Administrator:

```powershell
cd "C:\SCRIPT"
.\ScriptName.ps1
