[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True)]
    [string]$dataseturi,
    [Parameter(Mandatory=$True)]
    [string]$username,
    [Parameter(Mandatory=$True)]
    [string]$password,
    [Parameter(Mandatory=$True)]
    [string]$apptoken,
    [Parameter(Mandatory=$True)]
    [string]$socratahost
)
function Get-ADUsersForUpload {
    <#
       .SYNOPSIS
            Get employee information from active directory and JSON-ify it for upload to data.oregon.gov
       .DESCRIPTION
            Filter active directory accounts with the following specifications:
                * Include accounts that are Enabled
                * Exclude accounts that have no phone number
                * Exclude accounts that have no email address
                * Exclude accounts that have extensionAttribute10 set (HideFromState attribute)
            Sets the ismanager property to "yes" if the AD account has the directReports property set, otherwise it is "no"
    #>
    $properties = @("GivenName","sn","DisplayName","EmailAddress","Office","Department","Company","Description","POBox","telephoneNumber","City","directReports")
    $json = Get-ADUser -filter {
        (Enabled -eq "True") -and (telephoneNumber -ne "$null") -and (EmailAddress -ne "$null") -and (extensionAttribute10 -notlike "*")
        } -Properties $properties |
        select @{Name="firstname";Expression={$_.GivenName}},
        @{Name="lastname";Expression={$_.sn}},
        @{Name="emailaddress";Expression={$_.EmailAddress}},
        @{Name="department";Expression={$_.Department}},
        @{Name="company";Expression={$_.Company}},
        @{Name="description";Expression={$_.Description}},
        @{Name="pobox";Expression={$_.POBox}},
        @{Name="phonenumber";Expression={$_.telephoneNumber}},
        @{Name="city";Expression={$_.City}},
        @{Name="ismanager";Expression={if($_.directReports){"yes"} else {"no"}}},
        @{Name="lastupdatedate";Expression={Get-Date -Format g}} | ConvertTo-JSON
    return $json
}

# Import AD module if it isn't already loaded.  Only import it if it is available
if (Get-Module -ListAvailable -Name ActiveDirectory) {
    # AD module is available, check to see if it is already loaded
    if (-not (Get-Module -Name ActiveDirectory)) {
       # Module is not loaded, import it
       write-debug "Importing ActiveDirectory module"
       Import-Module ActiveDirectory
    } else {
       write-debug "ActiveDirectory module already loaded"
    }
} else {
    write-host "ActiveDirectory PowerShell module is not available"
    write-debug "Loaded modules:"
    write-debug (Get-Module)
    exit 1
}

# Populate the $json variable
$json = Get-ADUsersForUpload
write-debug $json

# Create auth information for HTTP Basic Auth
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$password)))

# Build headers
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Host",$socratahost)
$headers.Add("Accept","*/*")
$headers.Add("Authorization",("Basic {0}" -f $base64AuthInfo))
$headers.Add("Content-Length",$json.Length)
$headers.Add("X-App-Token",$apptoken)

# Post = Update existing records based on dataset key
# Put = Bulk replace entire dataset
# Use Put until logic is built into this
# script to handle deletes in an upsert
# https://dev.socrata.com/publishers/getting-started.html
$method = "Put"

$results = Invoke-RestMethod -Uri $dataseturi -Method $method -Headers $headers -Body $json -ContentType "application/json"

# The results contain how many records were created, updated, deleted, etc.
Write-Verbose $results
