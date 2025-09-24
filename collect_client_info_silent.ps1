# Script PowerShell SILENZIOSO per raccogliere informazioni client
# Versione: 2.1 - Silent Mode
# Creato il: 23 settembre 2025
# ESECUZIONE SILENZIOSA - Nessuna finestra visibile agli utenti

param(
    [string]$DatabasePath = "\\server\shared\client_data",
    [string]$OutputFormat = "CSV",
    [switch]$SendToDatabase,
    [string]$ServerEndpoint = "",
    [string]$LogPath = "$env:TEMP\MonitorIT_Collection.log",
    [switch]$SilentMode = $true
)

# Funzione per logging silenzioso
function Write-Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    try {
        Add-Content -Path $LogPath -Value $logEntry -Force
    }
    catch {
        # Se non riesce a scrivere il log, ignora silenziosamente
    }
}

# Funzione per catturare errori silenziosamente
function Invoke-SilentCommand {
    param(
        [scriptblock]$Command,
        [string]$Description = "Unknown operation"
    )
    
    try {
        $result = & $Command
        Write-Log "SUCCESS: $Description" "INFO"
        return $result
    }
    catch {
        Write-Log "ERROR: $Description - $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Get-SystemInfo {
    Write-Log "Avvio raccolta informazioni sistema" "INFO"
    
    $systemData = Invoke-SilentCommand -Description "Raccolta informazioni base" -Command {
        $computerName = $env:COMPUTERNAME
        $userName = $env:USERNAME
        $domain = $env:USERDOMAIN
        
        # Raccogli informazioni senza output visibile
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        $biosInfo = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
        $networkInfo = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | 
                      Where-Object {$_.IPEnabled -eq $true}
        
        [PSCustomObject]@{
            CollectionDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ComputerName = $computerName
            UserName = $userName
            Domain = $domain
            IPAddress = if ($networkInfo) { ($networkInfo | Select-Object -First 1).IPAddress[0] } else { "N/A" }
            MACAddress = if ($networkInfo) { ($networkInfo | Select-Object -First 1).MACAddress } else { "N/A" }
            OSName = if ($osInfo) { $osInfo.Caption } else { "Unknown" }
            OSVersion = if ($osInfo) { $osInfo.Version } else { "Unknown" }
            OSArchitecture = if ($osInfo) { $osInfo.OSArchitecture } else { "Unknown" }
            Manufacturer = if ($computerInfo) { $computerInfo.Manufacturer } else { "Unknown" }
            Model = if ($computerInfo) { $computerInfo.Model } else { "Unknown" }
            SystemType = if ($computerInfo) { $computerInfo.SystemType } else { "Unknown" }
            TotalRAM_GB = if ($computerInfo) { [math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2) } else { 0 }
            SerialNumber = if ($biosInfo) { $biosInfo.SerialNumber } else { "Unknown" }
            Disks = @()
        }
    }
    
    if ($systemData -eq $null) {
        Write-Log "Fallback a metodi alternativi per raccolta dati" "WARN"
        # Fallback con metodi più basic
        $systemData = [PSCustomObject]@{
            CollectionDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ComputerName = $env:COMPUTERNAME
            UserName = $env:USERNAME
            Domain = $env:USERDOMAIN
            IPAddress = "N/A"
            MACAddress = "N/A"
            OSName = "Windows"
            OSVersion = "Unknown"
            OSArchitecture = "Unknown"
            Manufacturer = "Unknown"
            Model = "Unknown"
            SystemType = "Unknown"
            TotalRAM_GB = 0
            SerialNumber = "Unknown"
            Disks = @()
        }
    }
    
    # Raccolta informazioni dischi
    $diskInfo = Invoke-SilentCommand -Description "Raccolta informazioni dischi" -Command {
        Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction SilentlyContinue | 
        Where-Object {$_.DriveType -eq 3}
    }
    
    if ($diskInfo) {
        foreach ($disk in $diskInfo) {
            $diskData = [PSCustomObject]@{
                Drive = $disk.DeviceID
                Label = if ($disk.VolumeName) { $disk.VolumeName } else { "Local Disk" }
                TotalSize_GB = [math]::Round($disk.Size / 1GB, 2)
                FreeSpace_GB = [math]::Round($disk.FreeSpace / 1GB, 2)
                UsedSpace_GB = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
                PercentUsed = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 1)
                FileSystem = $disk.FileSystem
            }
            $systemData.Disks += $diskData
        }
    }
    
    Write-Log "Raccolta dati completata: $($systemData.ComputerName)" "INFO"
    return $systemData
}

function Export-ToCSV {
    param($Data, $FilePath)
    
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
    
    $appendMode = Test-Path $FilePath
    $csvData | Export-Csv -Path $FilePath -NoTypeInformation -Append:$appendMode -Encoding UTF8
}

function Send-ToNetworkLocation {
    param($Data, $NetworkPath, $Format)
    
    $result = Invoke-SilentCommand -Description "Invio dati a percorso di rete" -Command {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $fileName = "$($Data.ComputerName)_$timestamp.$Format"
        $fullPath = Join-Path $NetworkPath $fileName
        
        $directory = Split-Path $fullPath -Parent
        if (!(Test-Path $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        
        switch ($Format.ToUpper()) {
            "CSV" { 
                $masterFile = Join-Path $NetworkPath "client_inventory.csv"
                Export-ToCSV -Data $Data -FilePath $masterFile
            }
            "JSON" { 
                $Data | ConvertTo-Json -Depth 3 | Out-File -FilePath $fullPath -Encoding UTF8 
            }
            default { 
                $Data | Out-String | Out-File -FilePath $fullPath -Encoding UTF8 
            }
        }
        
        return $fullPath
    }
    
    return $result -ne $null
}

function Send-ToAPI {
    param($Data, $Endpoint)
    
    $result = Invoke-SilentCommand -Description "Invio dati a API" -Command {
        $jsonData = $Data | ConvertTo-Json -Depth 3
        Invoke-RestMethod -Uri $Endpoint -Method POST -Body $jsonData -ContentType "application/json"
    }
    
    return $result -ne $null
}

# MAIN SCRIPT - ESECUZIONE SILENZIOSA
Write-Log "=== AVVIO RACCOLTA CLIENT SILENZIOSO ===" "INFO"
Write-Log "Computer: $env:COMPUTERNAME, Utente: $env:USERNAME" "INFO"

# Raccogli informazioni
$systemInfo = Get-SystemInfo

if ($systemInfo -eq $null) {
    Write-Log "CRITICO: Impossibile raccogliere informazioni di sistema" "ERROR"
    exit 1
}

# Salva backup locale sempre (nascosto)
$localFile = "$env:TEMP\$($systemInfo.ComputerName)_info_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
Invoke-SilentCommand -Description "Salvataggio backup locale" -Command {
    $systemInfo | Out-String | Out-File -FilePath $localFile -Encoding UTF8
}

Write-Log "Backup locale: $localFile" "INFO"

# Invia al percorso di rete se specificato
$networkSuccess = $false
if ($DatabasePath -and $DatabasePath -ne "") {
    $networkSuccess = Send-ToNetworkLocation -Data $systemInfo -NetworkPath $DatabasePath -Format $OutputFormat
    if ($networkSuccess) {
        Write-Log "Dati inviati con successo al database centrale" "INFO"
    } else {
        Write-Log "Errore nell'invio al database centrale - dati salvati solo localmente" "WARN"
    }
}

# Invia all'API se specificato
$apiSuccess = $false
if ($ServerEndpoint -and $ServerEndpoint -ne "") {
    $apiSuccess = Send-ToAPI -Data $systemInfo -Endpoint $ServerEndpoint
    if ($apiSuccess) {
        Write-Log "Dati inviati con successo all'API" "INFO"
    } else {
        Write-Log "Errore nell'invio all'API" "WARN"
    }
}

# Log finale
Write-Log "Raccolta completata - PC: $($systemInfo.ComputerName), IP: $($systemInfo.IPAddress), RAM: $($systemInfo.TotalRAM_GB)GB, Dischi: $($systemInfo.Disks.Count)" "INFO"
Write-Log "=== FINE RACCOLTA CLIENT ===" "INFO"

# Exit code per monitoraggio automatico
if ($networkSuccess -or $apiSuccess -or (Test-Path $localFile)) {
    exit 0  # Successo
} else {
    exit 1  # Errore
}