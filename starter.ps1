# --- Load config options ---
.$PSScriptRoot\config.ps1

Write-Host "`n[Job-Status] $(Get-Date) Job Start.`n---------------------------------------------`n"

# --- Query D42 for RDS instances ---
Write-Host "[Job-Status] $(Get-Date) Querying Device42 for RDS Instances...`n"
$query = Get-Content rds-doql.sql
$url = "https://$($_host)/services/data/v1.0/query/?query=$($query)&output_type=json"
$rows = curl.exe -k -u "$($_username):$($_password)" $url | ConvertFrom-Json
Write-Host "`n[Job-Status] $(Get-Date) Query Complete.`n"

Write-Host "[Job-Status] $(Get-Date) Starting DNS Sync..."
$devices = @()
$custom_fields = @()
foreach ($row in $rows) {
    $custom_fields += @{
        name  = $row.resource_name
        type  = 'url'
        key   = 'Related Resource'
        value = "https://$($_host)/admin/rackraj/resource/$($row.resource_pk)/"
    }
    $ips = @()

    foreach ($fqdn in $row.fqdns) {

        if ([string]::IsNullOrEmpty($fqdn) -ne $true) {
            $ips += @(Resolve-DnsName -Name $fqdn -Type A -ErrorAction SilentlyContinue | Where-object { $_.QueryType -ne "CNAME" } | Select-Object -ExpandProperty IPAddress) 
        }
        else {
            if ($_debug) {
                Write-Host "`n-----[Debug] $(Get-Date) [Warning] No FQDN found on resource $($row.resource_name): https://$($_host)/admin/rackraj/resource/$($row.resource_pk)/"
            }
        }  
    }
    $ips = $ips | Select-Object -Unique | Select-Object @{label = "ipaddress"; expression = { $_ } }
    
    if ($row.is_cluster -eq 1) {
        $notes = 'Service: Amazon Relational Database | Category: Database, Cluster'
    }
    else {
        $notes = 'Service: Amazon Relational Database | Category: Database'
    }
    $devices += @{
        device = @{
            name            = $row.resource_name
            type            = 'virtual'
            virtual_subtype = 'amazon service'
            tags            = 'AWS-RDS'
            notes           = $notes
        }
        ips    = @($ips)
    }
}
$data = @{}
$data["devices"] = $devices
Write-Host "`n[Job-Status] $(Get-Date) DNS Sync Complete.`n"

if ($_dry_run) {
    Write-Host "---[Dry Run] $(Get-Date) Writing to dry_run.json"
    $data["custom_fields"] = $custom_fields
    $data | ConvertTo-Json -Depth 99 | Out-File dry_run.json
}
else {
    Write-Host "[Job-Status] $(Get-Date) Posting devices..."
    # --- Pipe the payload to curl through stdin --- 
    $url = "https://$($_host)/api/1.0/devices/bulk/"
    $data | ConvertTo-Json -Compress -Depth 99 | curl.exe -k -u "$($_username):$($_password)" -X POST $url -H 'Content-Type: application/json' -d "@-"

    Write-Host "`n[Job-Status] $(Get-Date) Posting custom fields...`n"
    $url = "https://$($_host)/api/1.0/device/custom_field/"
    foreach ($custom_field in $custom_fields) {
        $custom_field | ConvertTo-Json -Compress -Depth 99 | curl.exe -k -u "$($_username):$($_password)" -X PUT $url -H 'Content-Type: application/json' -d "@-"
    }
}

Write-Host "`n---------------------------------------------`n[Job-Status] $(Get-Date) Job Complete`n"