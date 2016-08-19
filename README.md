# active-directory-attributes-to-socrata
Sync active directory user account attributes with the Socrata open data api (SODA) using powershell

## Syntax
```powershell
.\Sync-ADwithSocrata.ps1 
    -dataseturi <uri> 
    -username <username> 
    -password <password>
    -apptoken <apptoken>
    -socratahost <hostname>
    [-Verbose]
```
