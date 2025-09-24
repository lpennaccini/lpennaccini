# Script PowerShell per raccogliere informazioni client e salvarle in SQLite
# Versione: 3.0 - SQLite Integration
# Creato il: 23 settembre 2025

param(
    [string]$DatabasePath = "\\server\shared\client_data\inventory.db",
    [string]$OutputFormat = "SQLite",  # SQLite, CSV, JSON
    [string]$LogPath = "$env:TEMP\MonitorIT_Collection.log",
    [switch]$SilentMode = $true,
    [switch]$FallbackToCSV = $true
)

# Importa il modulo SQLite
$moduleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
Import-Module "$moduleRoot\SQLiteManager.psm1" -Force

# Funzione per logging
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    try {
        Add-Content -Path $LogPath -Value $logEntry -Force
    } catch {}
    
    if (!$SilentMode) {
        switch ($Level) {
            "ERROR" { Write-Host $logEntry -ForegroundColor Red }
            "WARN" { Write-Host $logEntry -ForegroundColor Yellow }
            "SUCCESS" { Write-Host $logEntry -ForegroundColor Green }
            default { Write-Host $logEntry }
        }
    }
}

function Get-SystemInfo {
    Write-Log "Avvio raccolta informazioni sistema" "INFO"
    
    try {
        $computerName = $env:COMPUTERNAME
        $userName = $env:USERNAME
        $domain = $env:USERDOMAIN
        
        # Raccogli informazioni senza output visibile
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        $biosInfo = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
        $networkInfo = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | 
                      Where-Object {$_.IPEnabled -eq $true}
        
        $systemData = [PSCustomObject]@{
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
        
        # Raccolta informazioni dischi
        $diskInfo = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction SilentlyContinue | 
                   Where-Object {$_.DriveType -eq 3}
        
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
    catch {
        Write-Log "Errore nella raccolta dati: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

function Save-ToSQLite {
    param($Data, $DatabasePath)
    
    try {
        Write-Log "Tentativo salvataggio in SQLite: $DatabasePath" "INFO"
        
        # Verifica se il percorso è accessibile
        $dbDir = Split-Path $DatabasePath -Parent
        if (!(Test-Path $dbDir)) {
            Write-Log "Creazione directory database: $dbDir" "INFO"
            New-Item -ItemType Directory -Path $dbDir -Force | Out-Null
        }
        
        # Prova a salvare nel database SQLite
        $result = Save-ComputerData -DatabasePath $DatabasePath -ComputerData $Data
        
        if ($result) {
            Write-Log "✓ Dati salvati con successo in SQLite" "SUCCESS"
            return $true
        } else {
            Write-Log "Errore salvataggio SQLite" "ERROR"
            return $false
        }
    }
    catch {
        Write-Log "Errore SQLite: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Save-ToCSV {
    param($Data, $FilePath)
    
    try {
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
        
        Write-Log "✓ Backup CSV salvato: $FilePath" "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Errore salvataggio CSV: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# MAIN SCRIPT
Write-Log "=== AVVIO RACCOLTA CLIENT (SQLite Mode) ===" "INFO"
Write-Log "Computer: $env:COMPUTERNAME, Database: $DatabasePath" "INFO"

# Installa PSSQLite se necessario
try {
    Write-Log "Verifica modulo SQLite..." "INFO"
    Initialize-SQLiteEnvironment -DatabasePath $DatabasePath | Out-Null
    Write-Log "✓ Modulo SQLite disponibile" "SUCCESS"
}
catch {
    Write-Log "Errore inizializzazione SQLite: $($_.Exception.Message)" "ERROR"
    if (!$FallbackToCSV) {
        Write-Log "CRITICO: SQLite non disponibile e fallback disabilitato" "ERROR"
        exit 1
    }
    Write-Log "Fallback a modalità CSV..." "WARN"
    $OutputFormat = "CSV"
}

# Raccogli informazioni
$systemInfo = Get-SystemInfo

if ($systemInfo -eq $null) {
    Write-Log "CRITICO: Impossibile raccogliere informazioni di sistema" "ERROR"
    exit 1
}

# Salva backup locale sempre
$localBackup = "$env:TEMP\$($systemInfo.ComputerName)_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
try {
    $systemInfo | ConvertTo-Json -Depth 3 | Out-File -FilePath $localBackup -Encoding UTF8
    Write-Log "Backup locale: $localBackup" "INFO"
}
catch {
    Write-Log "Errore backup locale: $($_.Exception.Message)" "WARN"
}

# Salva nel database principale
$mainSuccess = $false

if ($OutputFormat -eq "SQLite") {
    $mainSuccess = Save-ToSQLite -Data $systemInfo -DatabasePath $DatabasePath
    
    # Fallback a CSV se SQLite fallisce
    if (!$mainSuccess -and $FallbackToCSV) {
        Write-Log "Fallback automatico a CSV..." "WARN"
        $csvPath = $DatabasePath -replace "\.db$", "_fallback.csv"
        $mainSuccess = Save-ToCSV -Data $systemInfo -FilePath $csvPath
    }
}
elseif ($OutputFormat -eq "CSV") {
    $csvPath = $DatabasePath -replace "\.db$", ".csv"
    $mainSuccess = Save-ToCSV -Data $systemInfo -FilePath $csvPath
}

# Log finale
if ($mainSuccess) {
    Write-Log "✓ Raccolta completata con successo" "SUCCESS"
    Write-Log "PC: $($systemInfo.ComputerName), IP: $($systemInfo.IPAddress), RAM: $($systemInfo.TotalRAM_GB)GB, Dischi: $($systemInfo.Disks.Count)" "INFO"
    exit 0
} else {
    Write-Log "✗ Errore nel salvataggio dati principali" "ERROR"
    exit 1
}

Write-Log "=== FINE RACCOLTA CLIENT ===" "INFO"