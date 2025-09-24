# Script per visualizzare e analizzare i dati SQLite di MonitorIT
# Versione: 3.0 - SQLite Viewer

param(
    [string]$DatabasePath = ".\test_data\inventory.db",
    [string]$ReportType = "summary"  # summary, computers, disks, critical
)

# Importa il modulo SQLite
Import-Module PSSQLite -Force

function Show-DatabaseInfo {
    param([string]$DatabasePath)
    
    Write-Host "=== INFORMAZIONI DATABASE MONITORIT ===" -ForegroundColor Cyan
    Write-Host "Database: $DatabasePath" -ForegroundColor Yellow
    
    if (!(Test-Path $DatabasePath)) {
        Write-Host "❌ Database non trovato!" -ForegroundColor Red
        return
    }
    
    # Info generali
    $fileInfo = Get-Item $DatabasePath
    Write-Host "Dimensione file: $([math]::Round($fileInfo.Length / 1KB, 2)) KB" -ForegroundColor Green
    Write-Host "Ultima modifica: $($fileInfo.LastWriteTime)" -ForegroundColor Green
    
    # Conta record
    $computerCount = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(*) as count FROM computers").count
    $diskCount = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(*) as count FROM disks").count
    
    Write-Host "`n📊 CONTENUTO DATABASE:" -ForegroundColor Yellow
    Write-Host "  Computer records: $computerCount"
    Write-Host "  Disk records: $diskCount"
}

function Show-ComputerSummary {
    param([string]$DatabasePath)
    
    Write-Host "`n=== RIEPILOGO COMPUTER ===" -ForegroundColor Cyan
    
    $computers = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT 
    computer_name,
    user_name,
    ip_address,
    os_name,
    manufacturer,
    model,
    total_ram_gb,
    collection_date,
    (SELECT COUNT(*) FROM disks WHERE computer_id = computers.id) as disk_count
FROM computers 
ORDER BY collection_date DESC
"@
    
    if ($computers) {
        Write-Host "`n🖥️  COMPUTER REGISTRATI:" -ForegroundColor Yellow
        $computers | Format-Table -Property @(
            @{Name="Computer"; Expression={$_.computer_name}; Width=15},
            @{Name="Utente"; Expression={$_.user_name}; Width=12},
            @{Name="IP"; Expression={$_.ip_address}; Width=15},
            @{Name="OS"; Expression={$_.os_name.Substring(0,[Math]::Min(20,$_.os_name.Length))}; Width=20},
            @{Name="Produttore"; Expression={$_.manufacturer}; Width=12},
            @{Name="RAM(GB)"; Expression={$_.total_ram_gb}; Width=8},
            @{Name="Dischi"; Expression={$_.disk_count}; Width=6},
            @{Name="Ultima raccolta"; Expression={$_.collection_date}; Width=19}
        ) -AutoSize
        
        # Statistiche OS
        $osStats = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT os_name, COUNT(DISTINCT computer_name) as count 
FROM computers 
GROUP BY os_name 
ORDER BY count DESC
"@
        
        Write-Host "`n💻 DISTRIBUZIONE SISTEMI OPERATIVI:" -ForegroundColor Yellow
        $osStats | ForEach-Object {
            Write-Host "  $($_.os_name): $($_.count) computer" -ForegroundColor White
        }
        
        # Statistiche produttori
        $manufStats = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT manufacturer, COUNT(DISTINCT computer_name) as count 
FROM computers 
GROUP BY manufacturer 
ORDER BY count DESC
"@
        
        Write-Host "`n🏭 DISTRIBUZIONE PRODUTTORI:" -ForegroundColor Yellow
        $manufStats | ForEach-Object {
            Write-Host "  $($_.manufacturer): $($_.count) computer" -ForegroundColor White
        }
    } else {
        Write-Host "❌ Nessun computer trovato nel database" -ForegroundColor Red
    }
}

function Show-DiskAnalysis {
    param([string]$DatabasePath)
    
    Write-Host "`n=== ANALISI DISCHI ===" -ForegroundColor Cyan
    
    $disks = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT 
    c.computer_name,
    d.drive_letter,
    d.volume_label,
    d.total_size_gb,
    d.free_space_gb,
    d.used_space_gb,
    d.percent_used,
    d.file_system,
    d.collection_date
FROM disks d
JOIN computers c ON d.computer_id = c.id
ORDER BY d.percent_used DESC
"@
    
    if ($disks) {
        Write-Host "`n💿 TUTTI I DISCHI:" -ForegroundColor Yellow
        $disks | Format-Table -Property @(
            @{Name="Computer"; Expression={$_.computer_name}; Width=15},
            @{Name="Drive"; Expression={$_.drive_letter}; Width=6},
            @{Name="Etichetta"; Expression={$_.volume_label}; Width=12},
            @{Name="Totale(GB)"; Expression={[math]::Round($_.total_size_gb,1)}; Width=10},
            @{Name="Libero(GB)"; Expression={[math]::Round($_.free_space_gb,1)}; Width=10},
            @{Name="Usato%"; Expression={[math]::Round($_.percent_used,1)}; Width=7},
            @{Name="File System"; Expression={$_.file_system}; Width=10}
        ) -AutoSize
        
        # Statistiche utilizzo
        $avgUsage = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT AVG(percent_used) as avg FROM disks").avg
        $maxUsage = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT MAX(percent_used) as max FROM disks").max
        $totalSpace = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT SUM(total_size_gb) as total FROM disks").total
        
        Write-Host "`n📈 STATISTICHE UTILIZZO DISCHI:" -ForegroundColor Yellow
        Write-Host "  Utilizzo medio: $([math]::Round($avgUsage, 1))%"
        Write-Host "  Utilizzo massimo: $([math]::Round($maxUsage, 1))%"
        Write-Host "  Spazio totale rete: $([math]::Round($totalSpace, 1)) GB"
    } else {
        Write-Host "❌ Nessun disco trovato nel database" -ForegroundColor Red
    }
}

function Show-CriticalAlerts {
    param([string]$DatabasePath)
    
    Write-Host "`n=== ALERT CRITICI ===" -ForegroundColor Red
    
    # Dischi con utilizzo > 80%
    $criticalDisks = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT 
    c.computer_name,
    c.user_name,
    c.ip_address,
    d.drive_letter,
    d.volume_label,
    d.percent_used,
    d.free_space_gb,
    d.total_size_gb
FROM disks d
JOIN computers c ON d.computer_id = c.id
WHERE d.percent_used > 80
ORDER BY d.percent_used DESC
"@
    
    if ($criticalDisks -and $criticalDisks.Count -gt 0) {
        Write-Host "`n🚨 DISCHI CON SPAZIO CRITICO (>80%):" -ForegroundColor Red
        $criticalDisks | ForEach-Object {
            Write-Host "  ⚠️  $($_.computer_name) [$($_.drive_letter)] - $($_.percent_used)% utilizzato" -ForegroundColor Red
            Write-Host "     Utente: $($_.user_name) | IP: $($_.ip_address)"
            Write-Host "     Spazio libero: $([math]::Round($_.free_space_gb, 1)) GB su $([math]::Round($_.total_size_gb, 1)) GB totali"
            Write-Host ""
        }
    } else {
        Write-Host "✅ Nessun disco con utilizzo critico" -ForegroundColor Green
    }
    
    # Computer con poca RAM
    $lowRAM = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT computer_name, user_name, total_ram_gb, collection_date
FROM computers 
WHERE total_ram_gb < 4
ORDER BY total_ram_gb ASC
"@
    
    if ($lowRAM -and $lowRAM.Count -gt 0) {
        Write-Host "`n💾 COMPUTER CON POCA RAM (<4GB):" -ForegroundColor Yellow
        $lowRAM | ForEach-Object {
            Write-Host "  ⚠️  $($_.computer_name) - $($_.total_ram_gb) GB RAM (Utente: $($_.user_name))" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`n✅ Tutti i computer hanno RAM sufficiente" -ForegroundColor Green
    }
}

function Export-DatabaseReport {
    param([string]$DatabasePath, [string]$OutputPath = ".\reports")
    
    Write-Host "`n=== ESPORTAZIONE REPORT ===" -ForegroundColor Cyan
    
    if (!(Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    
    # Esporta computer
    $computers = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT * FROM computers ORDER BY computer_name"
    $computerFile = Join-Path $OutputPath "computers_$timestamp.csv"
    $computers | Export-Csv -Path $computerFile -NoTypeInformation -Encoding UTF8
    
    # Esporta dischi
    $disks = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT 
    c.computer_name,
    d.drive_letter,
    d.volume_label,
    d.total_size_gb,
    d.free_space_gb,
    d.percent_used,
    d.file_system,
    d.collection_date
FROM disks d
JOIN computers c ON d.computer_id = c.id
ORDER BY c.computer_name, d.drive_letter
"@
    $diskFile = Join-Path $OutputPath "disks_$timestamp.csv"
    $disks | Export-Csv -Path $diskFile -NoTypeInformation -Encoding UTF8
    
    Write-Host "✅ Report esportati:" -ForegroundColor Green
    Write-Host "  Computer: $computerFile"
    Write-Host "  Dischi: $diskFile"
}

# MAIN SCRIPT
Write-Host "=== MONITORIT DATABASE VIEWER ===" -ForegroundColor Cyan

if (!(Test-Path $DatabasePath)) {
    Write-Host "❌ Database non trovato: $DatabasePath" -ForegroundColor Red
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
    "export" {
        Export-DatabaseReport -DatabasePath $DatabasePath
    }
    default {
        Write-Host "`nTipi di report disponibili:" -ForegroundColor Yellow
        Write-Host "  summary   - Riepilogo computer (default)"
        Write-Host "  computers - Dettaglio computer"
        Write-Host "  disks     - Analisi dischi"
        Write-Host "  critical  - Alert critici"
        Write-Host "  all       - Report completo"
        Write-Host "  export    - Esporta in CSV"
    }
}

Write-Host "`n✅ Analisi completata!" -ForegroundColor Green