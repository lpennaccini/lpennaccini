# Script per visualizzare i dati SQLite di MonitorIT
# Versione: 3.0 - Clean Version

param(
    [string]$DatabasePath = ".\test_data\inventory.db",
    [string]$ReportType = "summary"
)

Import-Module PSSQLite -Force

function Show-DatabaseInfo {
    param([string]$DatabasePath)
    
    Write-Host "=== INFORMAZIONI DATABASE MONITORIT ===" -ForegroundColor Cyan
    Write-Host "Database: $DatabasePath" -ForegroundColor Yellow
    
    if (!(Test-Path $DatabasePath)) {
        Write-Host "Database non trovato!" -ForegroundColor Red
        return
    }
    
    $fileInfo = Get-Item $DatabasePath
    Write-Host "Dimensione file: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Green
    Write-Host "Ultima modifica: $($fileInfo.LastWriteTime)" -ForegroundColor Green
    
    $computerCount = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(*) as count FROM computers").count
    $diskCount = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(*) as count FROM disks").count
    
    Write-Host "`nCONTENUTO DATABASE:" -ForegroundColor Yellow
    Write-Host "  Computer records: $computerCount"
    Write-Host "  Disk records: $diskCount"
}

function Show-ComputerSummary {
    param([string]$DatabasePath)
    
    Write-Host "`n=== RIEPILOGO COMPUTER ===" -ForegroundColor Cyan
    
    $computers = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT computer_name, user_name, ip_address, os_name, manufacturer, model, total_ram_gb, collection_date, (SELECT COUNT(*) FROM disks WHERE computer_id = computers.id) as disk_count FROM computers ORDER BY collection_date DESC"
    
    if ($computers) {
        Write-Host "`nCOMPUTER REGISTRATI:" -ForegroundColor Yellow
        $computers | Format-Table -AutoSize
        
        $osStats = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT os_name, COUNT(DISTINCT computer_name) as count FROM computers GROUP BY os_name ORDER BY count DESC"
        
        Write-Host "`nDISTRIBUZIONE SISTEMI OPERATIVI:" -ForegroundColor Yellow
        $osStats | ForEach-Object {
            Write-Host "  $($_.os_name): $($_.count) computer" -ForegroundColor White
        }
        
        $manufStats = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT manufacturer, COUNT(DISTINCT computer_name) as count FROM computers GROUP BY manufacturer ORDER BY count DESC"
        
        Write-Host "`nDISTRIBUZIONE PRODUTTORI:" -ForegroundColor Yellow
        $manufStats | ForEach-Object {
            Write-Host "  $($_.manufacturer): $($_.count) computer" -ForegroundColor White
        }
    } else {
        Write-Host "Nessun computer trovato nel database" -ForegroundColor Red
    }
}

function Show-DiskAnalysis {
    param([string]$DatabasePath)
    
    Write-Host "`n=== ANALISI DISCHI ===" -ForegroundColor Cyan
    
    $disks = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT c.computer_name, d.drive_letter, d.volume_label, d.total_size_gb, d.free_space_gb, d.used_space_gb, d.percent_used, d.file_system, d.collection_date FROM disks d JOIN computers c ON d.computer_id = c.id ORDER BY d.percent_used DESC"
    
    if ($disks) {
        Write-Host "`nTUTTI I DISCHI:" -ForegroundColor Yellow
        $disks | Format-Table -AutoSize
        
        $avgUsage = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT AVG(percent_used) as avg FROM disks").avg
        $maxUsage = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT MAX(percent_used) as max FROM disks").max
        $totalSpace = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT SUM(total_size_gb) as total FROM disks").total
        
        Write-Host "`nSTATISTICHE UTILIZZO DISCHI:" -ForegroundColor Yellow
        Write-Host "  Utilizzo medio: $([math]::Round($avgUsage, 1))%"
        Write-Host "  Utilizzo massimo: $([math]::Round($maxUsage, 1))%"
        Write-Host "  Spazio totale rete: $([math]::Round($totalSpace, 1)) GB"
    } else {
        Write-Host "Nessun disco trovato nel database" -ForegroundColor Red
    }
}

function Show-CriticalAlerts {
    param([string]$DatabasePath)
    
    Write-Host "`n=== ALERT CRITICI ===" -ForegroundColor Red
    
    $criticalDisks = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT c.computer_name, c.user_name, c.ip_address, d.drive_letter, d.volume_label, d.percent_used, d.free_space_gb, d.total_size_gb FROM disks d JOIN computers c ON d.computer_id = c.id WHERE d.percent_used > 80 ORDER BY d.percent_used DESC"
    
    if ($criticalDisks -and $criticalDisks.Count -gt 0) {
        Write-Host "`nDISCHI CON SPAZIO CRITICO (>80%):" -ForegroundColor Red
        $criticalDisks | ForEach-Object {
            Write-Host "  ATTENZIONE: $($_.computer_name) [$($_.drive_letter)] - $($_.percent_used)% utilizzato" -ForegroundColor Red
            Write-Host "     Utente: $($_.user_name) | IP: $($_.ip_address)"
            Write-Host "     Spazio libero: $([math]::Round($_.free_space_gb, 1)) GB su $([math]::Round($_.total_size_gb, 1)) GB totali"
            Write-Host ""
        }
    } else {
        Write-Host "Nessun disco con utilizzo critico" -ForegroundColor Green
    }
    
    $lowRAM = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT computer_name, user_name, total_ram_gb, collection_date FROM computers WHERE total_ram_gb < 4 ORDER BY total_ram_gb ASC"
    
    if ($lowRAM -and $lowRAM.Count -gt 0) {
        Write-Host "`nCOMPUTER CON POCA RAM (<4GB):" -ForegroundColor Yellow
        $lowRAM | ForEach-Object {
            Write-Host "  ATTENZIONE: $($_.computer_name) - $($_.total_ram_gb) GB RAM (Utente: $($_.user_name))" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`nTutti i computer hanno RAM sufficiente" -ForegroundColor Green
    }
}

# MAIN SCRIPT
Write-Host "=== MONITORIT DATABASE VIEWER ===" -ForegroundColor Cyan

if (!(Test-Path $DatabasePath)) {
    Write-Host "Database non trovato: $DatabasePath" -ForegroundColor Red
    exit 1
}

Show-DatabaseInfo -DatabasePath $DatabasePath

switch ($ReportType.ToLower()) {
    "summary" {
        Show-ComputerSummary -DatabasePath $DatabasePath
    }
    "computers" {
        Show-ComputerSummary -DatabasePath $DatabasePath
    }
    "disks" {
        Show-DiskAnalysis -DatabasePath $DatabasePath
    }
    "critical" {
        Show-CriticalAlerts -DatabasePath $DatabasePath
    }
    "all" {
        Show-ComputerSummary -DatabasePath $DatabasePath
        Show-DiskAnalysis -DatabasePath $DatabasePath
        Show-CriticalAlerts -DatabasePath $DatabasePath
    }
    default {
        Write-Host "`nTipi di report disponibili:" -ForegroundColor Yellow
        Write-Host "  summary   - Riepilogo computer (default)"
        Write-Host "  computers - Dettaglio computer"
        Write-Host "  disks     - Analisi dischi"
        Write-Host "  critical  - Alert critici"
        Write-Host "  all       - Report completo"
    }
}

Write-Host "`nAnalisi completata!" -ForegroundColor Green