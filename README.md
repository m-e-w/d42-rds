- [Changelog](#changelog)
- [Instructions](#instructions)
- [Notes / Caveats](#notes)

# Changelog
## Patch 0.14 | 2021-08-17
m-e-w: Updated license agreement.

# Instructions
1. Rename config.ps1.example to config.ps1 and replace the default values with your own.  
    - Set $_dry_run to $false. Default is $true which will generate a file called dry_run.json with the payloads that will be sent so they can be inspected prior to running.
2. Open PowerShell and CD to the current working directory
3. Run by typing ./starter.ps1 

# Notes
1. You may see: "{"msg": "device not found", "code": 3}" on the first run. This is normal.  
   - Custom fields will not be created on the first run as the devices going to the devices/bulk endpoint will need to go through queue processing first on the MA. Once the RDS device records have been created all subsequent runs will successfully create/update custom fields. 