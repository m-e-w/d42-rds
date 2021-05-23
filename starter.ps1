# --- Load config options ---
.$PSScriptRoot\config.ps1

# --- Query D42 for RDS instances ---
$query = Get-Content rds-doql.sql
$url = "https://$($_host)/services/data/v1.0/query/?query=$($query)&output_type=json"
$rows = curl.exe -k -u "$($_username):$($_password)" $url | ConvertFrom-Json

# --- Format payload for bulk endpoint --- 
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
        $ips += @(Resolve-DnsName -Name $fqdn -Type A | Where-object { $_.QueryType -ne "CNAME" } | Select-Object -ExpandProperty IPAddress) 
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

if ($_dry_run) {
    $data | ConvertTo-Json -Depth 99 | Out-File dry_run.json
}
else {
    # --- Pipe the payload to curl through stdin & POST to the bulk devices endpoint --- 
    $url = "https://$($_host)/api/1.0/devices/bulk/"
    $data | ConvertTo-Json -Compress -Depth 99 | curl.exe -k -u "$($_username):$($_password)" -X POST $url -H 'Content-Type: application/json' -d "@-"

    $url = "https://$($_host)/api/1.0/device/custom_field/"
    foreach ($custom_field in $custom_fields) {
        $custom_field | ConvertTo-Json -Compress -Depth 99 | curl.exe -k -u "$($_username):$($_password)" -X PUT $url -H 'Content-Type: application/json' -d "@-"
    }
}



