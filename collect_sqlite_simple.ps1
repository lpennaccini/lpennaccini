# Script PowerShell per raccogliere informazioni e salvarle in SQLite
# Versione: 3.0 - SQLite Working Version

param(
    [string]$DatabasePath = ".\test_data\inventory.db",
    [switch]$SilentMode = $false
)

# Importa il modulo SQLite semplificato
$moduleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
Import-Module "$moduleRoot\SQLiteManager_Simple.psm1" -Force

function Write-LogMessage {
    param([string]$Message, [string]$Level = "INFO")
    
    if (!$SilentMode) {
        $timestamp = Get-Date -Format "HH:mm:ss"
        switch ($Level) {
            "ERROR" { Write-Host "[$timestamp] ❌ $Message" -ForegroundColor Red }
            "WARN" { Write-Host "[$timestamp] ⚠️  $Message" -ForegroundColor Yellow }
            "SUCCESS" { Write-Host "[$timestamp] ✅ $Message" -ForegroundColor Green }
            default { Write-Host "[$timestamp] ℹ️  $Message" -ForegroundColor Cyan }
        }
    }
}

function Get-SystemInfo {
    Write-LogMessage "Raccolta informazioni sistema..." "INFO"
    
    try {
        $computerName = $env:COMPUTERNAME
        $userName = $env:USERNAME
        $domain = $env:USERDOMAIN
        
        # Informazioni base
        $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        $computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
        $biosInfo = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
        $networkInfo = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | 
                      Where-Object {$_.IPEnabled -eq $true} | Select-Object -First 1
        
        $systemData = [PSCustomObject]@{
            CollectionDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            ComputerName = $computerName
            UserName = $userName
            Domain = $domain
            IPAddress = if ($networkInfo -and $networkInfo.IPAddress) { $networkInfo.IPAddress[0] } else { "N/A" }
            MACAddress = if ($networkInfo) { $networkInfo.MACAddress } else { "N/A" }
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
        
        # Informazioni dischi
        $diskInfo = Get-CimInstance -ClassName Win32_LogicalDisk -ErrorAction SilentlyContinue | 
                   Where-Object {$_.DriveType -eq 3}
        
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
        
        Write-LogMessage "Dati raccolti per: $computerName" "SUCCESS"
        return $systemData
    }
    catch {
        Write-LogMessage "Errore raccolta dati: $($_.Exception.Message)" "ERROR"
        return $null
    }
}

# MAIN SCRIPT
Write-LogMessage "=== MONITORIT SQLITE COLLECTION ===" "INFO"
Write-LogMessage "Database: $DatabasePath" "INFO"

# Raccogli informazioni
$systemInfo = Get-SystemInfo

if ($systemInfo -eq $null) {
    Write-LogMessage "Impossibile raccogliere informazioni sistema" "ERROR"
    exit 1
}

# Salva nel database SQLite
Write-LogMessage "Salvataggio in database SQLite..." "INFO"

try {
    $result = Save-ComputerData -DatabasePath $DatabasePath -ComputerData $systemInfo
    
    if ($result) {
        Write-LogMessage "Dati salvati con successo!" "SUCCESS"
        Write-LogMessage "Computer: $($systemInfo.ComputerName)" "INFO"
        Write-LogMessage "IP: $($systemInfo.IPAddress)" "INFO"
        Write-LogMessage "RAM: $($systemInfo.TotalRAM_GB) GB" "INFO"
        Write-LogMessage "Dischi: $($systemInfo.Disks.Count)" "INFO"
        
        # Mostra statistiche database
        Write-LogMessage "`nStatistiche database:" "INFO"
        $stats = Get-DatabaseSummary -DatabasePath $DatabasePath
        if ($stats) {
            Write-LogMessage "Totale computer nel DB: $($stats.TotalComputers)" "INFO"
            Write-LogMessage "Ultima raccolta: $($stats.LastCollection)" "INFO"
            
            if ($stats.CriticalDisks -and $stats.CriticalDisks.Count -gt 0) {
                Write-LogMessage "⚠️  Dischi critici trovati: $($stats.CriticalDisks.Count)" "WARN"
            }
        }
    } else {
        Write-LogMessage "Errore nel salvataggio dati" "ERROR"
        exit 1
    }
}
catch {
    Write-LogMessage "Errore SQLite: $($_.Exception.Message)" "ERROR"
    exit 1
}

Write-LogMessage "=== RACCOLTA COMPLETATA ===" "SUCCESS"