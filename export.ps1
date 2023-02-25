$file_data = Get-Content $PSScriptRoot\credentials.txt
$users = $file_data[0] -split "="
$passwords = $file_data[1] -split "="
$urls = $file_data[2] -split "="
$ports = $file_data[3] -split "="
$userid = $users[1]
$password = $passwords[1]
$uri = "$($urls[1]):$($ports[1])/json"
$postParams = @{cmd = 'login' }
$json = Invoke-WebRequest -Uri $uri -Method POST -Body ($postParams | ConvertTo-Json) -ContentType application/json
$releases = ConvertFrom-Json $json.content
$sessionstr = $userid + ':' + $releases.session + ':' + $password
$md5 = New-Object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
$utf8 = New-Object -TypeName System.Text.UTF8Encoding
$hash = [System.BitConverter]::ToString($md5.ComputeHash($utf8.GetBytes($sessionstr))).Replace("-", "")
$postParams = @{cmd = 'login'; session = $releases.session; response = $hash }
$json = Invoke-WebRequest -Uri $uri -Method POST -Body ($postParams | ConvertTo-Json) -ContentType application/json
$releases = ConvertFrom-Json $json.content
$session = $releases.session

$cameraNames = @()
$startDates = @()
$startTimes = @()
$endDates = @()
$endTimes = @()
$statusList = @()
$csvfile = Import-Csv $PSScriptRoot\export.csv
$csvfile |`
    ForEach-Object {
    $cameraNames += $_.Camera
    $startDates += $_.StartDate
    $startTimes += $_.StartTime
    $endDates += $_.endDate
    $endTimes += $_.endTime
    $statusList += $_.Status
}
if ($cameraNames.Count -ne 0) {
    for ($i = 0; $i -lt $cameraNames.Count; $i++) {
        $results = $null
        $flag = $true
        if ($statusList[$i] -ne "done") {
            $tz = [TimeZoneInfo]::FindSystemTimeZoneById("E. Australia Standard Time");
            $DateTimeObject = [Datetime]::ParseExact("$($startDates[$i]) $($startTimes[$i])", "yyyy-MM-dd H:mm", $null)
            $DateTimeObject = [TimeZoneInfo]::ConvertTimeToUtc($DateTimeObject, $tz);
            $startDate = $DateTimeObject | Get-Date -UFormat "%s";
            $DateTimeObject = [Datetime]::ParseExact("$($endDates[$i]) $($endTimes[$i])", "yyyy-MM-dd H:mm", $null)
            $DateTimeObject = [TimeZoneInfo]::ConvertTimeToUtc($DateTimeObject, $tz);
            $endDate = $DateTimeObject | Get-Date -UFormat "%s";
            $postParams = @{cmd = 'cliplist'; session = $session; camera = $cameraNames[$i]; view = 'all' }
            $json = Invoke-WebRequest -Uri $uri -Method POST -Body ($postParams | ConvertTo-Json) -ContentType application/json
            $releases = ConvertFrom-Json $json.content
            $match = $null
            foreach ($elem in $releases.data) {
                if ($elem.path.Contains('.bvr')) {
                    if (($startDate -ge $elem.date) -and ($endDate -le ($elem.date + $elem.msec))) {
                        $match = $elem
                        break
                    }
                }
            }
            
            if ($match -ne $null) {
                $startms = 0
                if ($match.date -lt $startDate) {
                    $startms = $startDate - $match.date
                }
                $msec = $endDate - $startDate
                if ($msec -lt 0) {
                    $msec = 0
                }
                $postParams = @{cmd = 'export'; session = $session; path = $match.path; startms = $startms * 1000; msec = $msec * 1000; audio = $false; overlay = $false; format = 1; profile = 0; reencode = $false; substream = $false }
                $json = Invoke-WebRequest -Uri $uri -Method POST -Body ($postParams | ConvertTo-Json) -ContentType application/json
                $releases = ConvertFrom-Json $json.content
                $results = $releases.data.path
            }
            else {
                $results = $null
            }
            while ($flag) {
                $postParams = @{cmd = 'export'; session = $session }
                $json = Invoke-WebRequest -Uri $uri -Method POST -Body ($postParams | ConvertTo-Json) -ContentType application/json
                $releases = ConvertFrom-Json $json.content
                Write-Host "------------next result----------"
                $temp = $releases.data | where { $_.path -eq $results }
                   
                if ($temp) {
                    Write-Host "$($results): $($temp.status)"
                    $j = 0
                    $csvfile | foreach {
                        $j++
                        if ($j -eq $i + 1) { $_.Status = $temp.status }
                    }
                    $csvfile | Export-Csv -Path $PSScriptRoot\export.csv -NoTypeInformation
                    if (($temp.status -eq "done") -or ($temp.status -eq "error")) {
                        $flag = $false
                    }
                    else {
                        Start-Sleep -Seconds 10
                    }
                }
                else {
                    Write-Host  "$($results): null"
                    $j = 0
                    $csvfile | foreach {
                        $j++
                        if ($j -eq $i + 1) { $_.Status = "null" }
                    }
                    $csvfile | Export-Csv -Path $PSScriptRoot\export.csv -NoTypeInformation
                    $flag = $false
                }
            }
        }
        else {
            $results = "0"
        }

    }
  
    Write-Host "finished"
}
else {
    Write-Host "finished"
}
