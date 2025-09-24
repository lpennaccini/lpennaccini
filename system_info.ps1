# Script PowerShell per raccogliere informazioni di sistema
# Creato il: 23 settembre 2025

# Ottieni le informazioni di sistema
$computerName = $env:COMPUTERNAME
$userName = $env:USERNAME
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
$computerInfo = Get-CimInstance -ClassName Win32_ComputerSystem
$diskInfo = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3}

# Formatta le informazioni sui dischi
$diskDetails = ""
foreach ($disk in $diskInfo) {
    $totalSize = [math]::Round($disk.Size / 1GB, 2)
    $freeSpace = [math]::Round($disk.FreeSpace / 1GB, 2)
    $usedSpace = [math]::Round(($disk.Size - $disk.FreeSpace) / 1GB, 2)
    $percentUsed = [math]::Round((($disk.Size - $disk.FreeSpace) / $disk.Size) * 100, 1)
    
    $diskDetails += "Disco $($disk.DeviceID) ($($disk.VolumeName))`n"
    $diskDetails += "  - Dimensione totale: $totalSize GB`n"
    $diskDetails += "  - Spazio utilizzato: $usedSpace GB ($percentUsed%)`n"
    $diskDetails += "  - Spazio libero: $freeSpace GB`n"
    $diskDetails += "  - File system: $($disk.FileSystem)`n`n"
}

# Formatta le informazioni
$systemInfo = @"
=== INFORMAZIONI DI SISTEMA ===
Data di generazione: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")

Nome del PC: $computerName
Nome utente: $userName
Sistema operativo: $($osInfo.Caption) $($osInfo.Version)
Architettura: $($osInfo.OSArchitecture)
Modello del PC: $($computerInfo.Manufacturer) $($computerInfo.Model)
Tipo di sistema: $($computerInfo.SystemType)
Memoria totale: $([math]::Round($computerInfo.TotalPhysicalMemory / 1GB, 2)) GB

=== INFORMAZIONI DISCHI FISSI ===
$diskDetails
=== FINE REPORT ===
"@

# Percorso del file di output
$outputPath = ".\system_info.txt"

try {
    # Salva le informazioni nel file
    $systemInfo | Out-File -FilePath $outputPath -Encoding UTF8
    
    Write-Host "Informazioni di sistema salvate con successo in: $outputPath" -ForegroundColor Green
    Write-Host "Contenuto del file:" -ForegroundColor Yellow
    Write-Host $systemInfo
}
catch {
    Write-Error "Errore durante il salvataggio del file: $($_.Exception.Message)"
}

# Chiedi se aprire il file
$choice = Read-Host "`nVuoi aprire il file di testo? (S/N)"
if ($choice -eq "S" -or $choice -eq "s") {
    Start-Process notepad.exe -ArgumentList $outputPath
}