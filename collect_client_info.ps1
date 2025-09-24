# Script PowerShell per raccogliere informazioni client per database centrale
# Versione: 2.0 - Network Ready
# Creato il: 23 settembre 2025

param(
    [string]$DatabasePath = "\\server\shared\client_data",  # Percorso condiviso di rete
    [string]$OutputFormat = "CSV",                          # CSV, JSON, o TXT
    [switch]$SendToDatabase,                                # Flag per invio a DB
    [string]$ServerEndpoint = ""                            # URL endpoint per API REST
)

function Get-SystemInfo {
    try {
        # Informazioni base di sistema
        $computerName = $env:COMPUTERNAME
        $userName = $env:USERNAME
        $domain = $env:USERDOMAIN
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
        $computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem
        $biosInfo = Get-CimInstance -ClassName Win32_BIOS
        $networkInfo = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled -eq $true}
        
        # Informazioni dischi
        $diskInfo = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3}
        
        # Crea oggetto con tutte le informazioni
        $systemData = [PSCustomObject]@{
            CollectionDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ComputerName = $computerName
            UserName = $userName
            Domain = $domain
            IPAddress = ($networkInfo | Select-Object -First 1).IPAddress[0]
            MACAddress = ($networkInfo | Select-Object -First 1).MACAddress
            OSName = $osInfo.Caption
            OSVersion = $osInfo.Version
            OSArchitecture = $osInfo.OSArchitecture
            Manufacturer = $computerInfo.Manufacturer
            Model = $computerInfo.Model
            SystemType = $computerInfo.SystemType
            TotalRAM_GB = [math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)
            SerialNumber = $biosInfo.SerialNumber
            Disks = @()
        }
        
        # Aggiungi informazioni dischi
        foreach ($disk in $diskInfo) {
            $diskData = [PSCustomObject]@{
                Drive = $disk.DeviceID
                Label = $disk.VolumeName
                TotalSize_GB = [math]::Round($disk.Size / 1GB, 2)
                FreeSpace_GB = [math]::Round($disk.FreeSpace / 1GB, 2)
                UsedSpace_GB = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
                PercentUsed = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 1)
                FileSystem = $disk.FileSystem
            }
            $systemData.Disks += $diskData
        }
        
        return $systemData
    }
    catch {
        Write-Error "Errore nella raccolta dati: $($_.Exception.Message)"
        return $null
    }
}

function Export-ToCSV {
    param($Data, $FilePath)
    
    # Crea record CSV con dischi come stringa JSON
    $csvData = [PSCustomObject]@{
        CollectionDate = $Data.CollectionDate
        ComputerName = $Data.ComputerName
        UserName = $Data.UserName
        Domain = $Data.Domain
        IPAddress = $Data.IPAddress
        MACAddress = $Data.MACAddress
        OSName = $Data.OSName
        OSVersion = $Data.OSVersion
        OSArchitecture = $Data.OSArchitecture
        Manufacturer = $Data.Manufacturer
        Model = $Data.Model
        SystemType = $Data.SystemType
        TotalRAM_GB = $Data.TotalRAM_GB
        SerialNumber = $Data.SerialNumber
        DisksInfo = ($Data.Disks | ConvertTo-Json -Compress)
    }
    
    # Verifica se il file esiste per decidere se aggiungere header
    $appendMode = Test-Path $FilePath
    $csvData | Export-Csv -Path $FilePath -NoTypeInformation -Append:$appendMode -Encoding UTF8
}

function Export-ToJSON {
    param($Data, $FilePath)
    
    $Data | ConvertTo-Json -Depth 3 | Out-File -FilePath $FilePath -Encoding UTF8
}

function Send-ToNetworkLocation {
    param($Data, $NetworkPath, $Format)
    
    try {
        # Crea nome file univoco
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $fileName = "$($Data.ComputerName)_$timestamp.$Format"
        $fullPath = Join-Path $NetworkPath $fileName
        
        # Assicurati che la directory esista
        $directory = Split-Path $fullPath -Parent
        if (!(Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        
        switch ($Format.ToUpper()) {
            "CSV" { 
                # Per CSV, appendi al file master
                $masterFile = Join-Path $NetworkPath "client_inventory.csv"
                Export-ToCSV -Data $Data -FilePath $masterFile
            }
            "JSON" { Export-ToJSON -Data $Data -FilePath $fullPath }
            default { 
                $Data | Out-String | Out-File -FilePath $fullPath -Encoding UTF8 
            }
        }
        
        Write-Host "Dati inviati con successo a: $fullPath" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Errore nell'invio a percorso di rete: $($_.Exception.Message)"
        return $false
    }
}

function Send-ToAPI {
    param($Data, $Endpoint)
    
    try {
        $jsonData = $Data | ConvertTo-Json -Depth 3
        $response = Invoke-RestMethod -Uri $Endpoint -Method POST -Body $jsonData -ContentType "application/json"
        Write-Host "Dati inviati con successo all'API: $Endpoint" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Error "Errore nell'invio all'API: $($_.Exception.Message)"
        return $false
    }
}

# MAIN SCRIPT
Write-Host "=== RACCOLTA INFORMAZIONI CLIENT ===" -ForegroundColor Cyan
Write-Host "Computer: $env:COMPUTERNAME" -ForegroundColor Yellow

# Raccogli informazioni
$systemInfo = Get-SystemInfo

if ($systemInfo -eq $null) {
    Write-Error "Impossibile raccogliere le informazioni di sistema"
    exit 1
}

# Salva localmente come backup
$localFile = ".\$($systemInfo.ComputerName)_info_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$systemInfo | Out-String | Out-File -FilePath $localFile -Encoding UTF8
Write-Host "Backup locale salvato: $localFile" -ForegroundColor Green

# Invia al percorso di rete se specificato
if ($DatabasePath -and $DatabasePath -ne "") {
    $success = Send-ToNetworkLocation -Data $systemInfo -NetworkPath $DatabasePath -Format $OutputFormat
    if (!$success) {
        Write-Warning "Fallback: impossibile inviare al percorso di rete, dati salvati solo localmente"
    }
}

# Invia all'API se specificato
if ($ServerEndpoint -and $ServerEndpoint -ne "") {
    $apiSuccess = Send-ToAPI -Data $systemInfo -Endpoint $ServerEndpoint
    if (!$apiSuccess) {
        Write-Warning "Impossibile inviare all'API endpoint"
    }
}

Write-Host "`n=== RIEPILOGO INFORMAZIONI RACCOLTE ===" -ForegroundColor Cyan
Write-Host "Computer: $($systemInfo.ComputerName)"
Write-Host "Utente: $($systemInfo.UserName)"
Write-Host "IP: $($systemInfo.IPAddress)"
Write-Host "OS: $($systemInfo.OSName)"
Write-Host "RAM: $($systemInfo.TotalRAM_GB) GB"
Write-Host "Dischi: $($systemInfo.Disks.Count)"

Write-Host "`nScript completato!" -ForegroundColor Green