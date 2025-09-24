# Script di query e report per database SQLite MonitorIT
# Versione: 3.0 - SQLite Analytics
# Creato il: 23 settembre 2025

param(
    [string]$DatabasePath = "\\server\shared\client_data\inventory.db",
    [string]$ReportType = "summary",  # summary, detailed, critical, trends, export
    [string]$OutputPath = ".\reports",
    [string]$ComputerFilter = "",
    [string]$FromDate = "",
    [string]$ToDate = "",
    [switch]$ExportToHTML,
    [switch]$ExportToExcel,
    [switch]$ShowCriticalAlerts
)

# Importa il modulo SQLite
$moduleRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
Import-Module "$moduleRoot\SQLiteManager.psm1" -Force

function Show-DatabaseSummary {
    param($DatabasePath)
    
    Write-Host "=== RIEPILOGO DATABASE MONITORIT ===" -ForegroundColor Cyan
    
    $stats = Get-DatabaseStatistics -DatabasePath $DatabasePath
    
    if ($stats) {
        Write-Host "`n📊 STATISTICHE GENERALI:" -ForegroundColor Yellow
        Write-Host "  Computer totali: $($stats.TotalComputers)"
        Write-Host "  Record totali: $($stats.TotalRecords)"
        Write-Host "  Ultima raccolta: $($stats.LastCollection)"
        
        Write-Host "`n🖥️  DISTRIBUZIONE SISTEMI OPERATIVI:" -ForegroundColor Yellow
        $stats.OSDistribution | ForEach-Object {
            Write-Host "  $($_.os_name): $($_.count) PC" -ForegroundColor White
        }
        
        Write-Host "`n🏭 DISTRIBUZIONE PRODUTTORI:" -ForegroundColor Yellow
        $stats.ManufacturerDistribution | ForEach-Object {
            Write-Host "  $($_.manufacturer): $($_.count) PC" -ForegroundColor White
        }
        
        if ($stats.CriticalDisks.Count -gt 0) {
            Write-Host "`n⚠️  DISCHI CON UTILIZZO CRITICO (>80%):" -ForegroundColor Red
            $stats.CriticalDisks | ForEach-Object {
                Write-Host "  $($_.computer_name) [$($_.drive_letter)] - $($_.percent_used)% utilizzato ($($_.free_space_gb)GB liberi)" -ForegroundColor Red
            }
        } else {
            Write-Host "`n✅ Nessun disco con utilizzo critico" -ForegroundColor Green
        }
    }
}

function Get-DetailedInventory {
    param($DatabasePath, $ComputerFilter, $FromDate, $ToDate)
    
    Write-Host "=== INVENTARIO DETTAGLIATO ===" -ForegroundColor Cyan
    
    $inventory = Get-ComputerInventory -DatabasePath $DatabasePath -ComputerName $ComputerFilter -FromDate $FromDate -ToDate $ToDate -IncludeDisks
    
    if ($inventory) {
        $inventory | ForEach-Object {
            Write-Host "`n🖥️  $($_.computer_name)" -ForegroundColor Green
            Write-Host "  📅 Data raccolta: $($_.collection_date)"
            Write-Host "  👤 Utente: $($_.user_name)"
            Write-Host "  🌐 IP: $($_.ip_address)"
            Write-Host "  💻 OS: $($_.os_name)"
            Write-Host "  🏭 Produttore: $($_.manufacturer) $($_.model)"
            Write-Host "  💾 RAM: $($_.total_ram_gb) GB"
            Write-Host "  💿 Dischi: $($_.disk_count) ($($_.total_disk_space_gb) GB totali, $($_.avg_disk_usage_percent)% utilizzo medio)"
            
            if ($_.DiskDetails) {
                Write-Host "    📀 Dettaglio dischi:" -ForegroundColor Yellow
                $_.DiskDetails | ForEach-Object {
                    $status = if ($_.percent_used -gt 80) { "⚠️" } else { "✅" }
                    Write-Host "      $status $($_.drive_letter) [$($_.volume_label)] - $($_.total_size_gb)GB ($($_.percent_used)% usato)"
                }
            }
        }
        
        return $inventory
    }
    
    return $null
}

function Get-CriticalAlerts {
    param($DatabasePath)
    
    Write-Host "=== ALERT CRITICI ===" -ForegroundColor Red
    
    # Query per dischi critici
    $criticalQuery = @"
SELECT 
    c.computer_name,
    c.user_name,
    c.ip_address,
    d.drive_letter,
    d.volume_label,
    d.percent_used,
    d.free_space_gb,
    d.total_size_gb,
    c.collection_date
FROM disks d
JOIN computers c ON d.computer_id = c.id
WHERE d.percent_used > 80
AND d.collection_date = (
    SELECT MAX(collection_date) 
    FROM disks d2 
    WHERE d2.computer_id = d.computer_id
)
ORDER BY d.percent_used DESC
"@

    $criticalDisks = Invoke-SqliteQuery -DataSource $DatabasePath -Query $criticalQuery
    
    if ($criticalDisks) {
        Write-Host "`n⚠️  DISCHI CON SPAZIO CRITICO:" -ForegroundColor Red
        $criticalDisks | ForEach-Object {
            Write-Host "  🚨 $($_.computer_name) [$($_.drive_letter)] - $($_.percent_used)% pieno" -ForegroundColor Red
            Write-Host "     Utente: $($_.user_name), IP: $($_.ip_address)"
            Write-Host "     Spazio libero: $($_.free_space_gb)GB su $($_.total_size_gb)GB totali"
            Write-Host "     Data rilevazione: $($_.collection_date)"
            Write-Host ""
        }
    }
    
    # Query per computer non aggiornati (oltre 7 giorni)
    $staleQuery = @"
SELECT 
    computer_name,
    MAX(collection_date) as last_seen,
    julianday('now') - julianday(MAX(collection_date)) as days_ago
FROM computers
GROUP BY computer_name
HAVING days_ago > 7
ORDER BY days_ago DESC
"@

    $staleComputers = Invoke-SqliteQuery -DataSource $DatabasePath -Query $staleQuery
    
    if ($staleComputers) {
        Write-Host "`n📅 COMPUTER NON AGGIORNATI (oltre 7 giorni):" -ForegroundColor Yellow
        $staleComputers | ForEach-Object {
            Write-Host "  ⏰ $($_.computer_name) - ultimo aggiornamento: $($_.last_seen) ($([math]::Round($_.days_ago, 0)) giorni fa)" -ForegroundColor Yellow
        }
    }
    
    return @{
        CriticalDisks = $criticalDisks
        StaleComputers = $staleComputers
    }
}

function Export-ToHTML {
    param($Data, $OutputPath, $Title)
    
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>$Title - MonitorIT</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; text-align: center; margin-bottom: 20px; }
        .section { background: white; margin: 20px 0; padding: 20px; border-radius: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        .stats { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; margin: 20px 0; }
        .stat-box { background: linear-gradient(45deg, #f0f2f5, #e1e8ed); padding: 15px; border-radius: 8px; text-align: center; border-left: 4px solid #667eea; }
        .stat-number { font-size: 2em; font-weight: bold; color: #333; }
        .stat-label { color: #666; font-size: 0.9em; }
        table { border-collapse: collapse; width: 100%; margin: 15px 0; }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background: linear-gradient(45deg, #667eea, #764ba2); color: white; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .critical { background-color: #ffebee !important; }
        .warning { background-color: #fff3e0 !important; }
        .success { background-color: #e8f5e8 !important; }
        .alert { padding: 10px; margin: 10px 0; border-radius: 5px; }
        .alert-danger { background-color: #f8d7da; border: 1px solid #f5c6cb; color: #721c24; }
        .alert-warning { background-color: #fff3cd; border: 1px solid #ffeaa7; color: #856404; }
        .chart { margin: 20px 0; text-align: center; }
    </style>
</head>
<body>
    <div class="header">
        <h1>📊 $Title</h1>
        <p>Generato il: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")</p>
    </div>
"@

    # Aggiungi contenuto specifico basato sul tipo di report
    if ($Data.Stats) {
        $htmlContent += @"
    <div class="section">
        <h2>📈 Statistiche Generali</h2>
        <div class="stats">
            <div class="stat-box">
                <div class="stat-number">$($Data.Stats.TotalComputers)</div>
                <div class="stat-label">Computer Totali</div>
            </div>
            <div class="stat-box">
                <div class="stat-number">$($Data.Stats.TotalRecords)</div>
                <div class="stat-label">Record Totali</div>
            </div>
            <div class="stat-box">
                <div class="stat-number">$($Data.Stats.CriticalDisks.Count)</div>
                <div class="stat-label">Dischi Critici</div>
            </div>
        </div>
    </div>
"@
    }

    if ($Data.Inventory) {
        $htmlContent += @"
    <div class="section">
        <h2>🖥️ Inventario Computer</h2>
        <table>
            <tr>
                <th>Computer</th>
                <th>Utente</th>
                <th>IP</th>
                <th>Sistema Operativo</th>
                <th>RAM (GB)</th>
                <th>Dischi</th>
                <th>Utilizzo Medio</th>
                <th>Ultima Raccolta</th>
            </tr>
            $($Data.Inventory | ForEach-Object {
                $rowClass = if ($_.avg_disk_usage_percent -gt 80) { "critical" } elseif ($_.avg_disk_usage_percent -gt 60) { "warning" } else { "success" }
                "<tr class='$rowClass'>
                    <td>$($_.computer_name)</td>
                    <td>$($_.user_name)</td>
                    <td>$($_.ip_address)</td>
                    <td>$($_.os_name)</td>
                    <td>$($_.total_ram_gb)</td>
                    <td>$($_.disk_count) ($($_.total_disk_space_gb) GB)</td>
                    <td>$($_.avg_disk_usage_percent)%</td>
                    <td>$($_.collection_date)</td>
                </tr>"
            } | Out-String)
        </table>
    </div>
"@
    }

    $htmlContent += @"
    <div class="section">
        <p style="text-align: center; color: #666; font-size: 0.9em;">
            Report generato da MonitorIT v3.0 - Sistema di Inventario Client con SQLite
        </p>
    </div>
</body>
</html>
"@

    $htmlFile = Join-Path $OutputPath "MonitorIT_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    $htmlContent | Out-File -FilePath $htmlFile -Encoding UTF8
    
    Write-Host "✅ Report HTML generato: $htmlFile" -ForegroundColor Green
    return $htmlFile
}

function Show-TrendAnalysis {
    param($DatabasePath)
    
    Write-Host "=== ANALISI TENDENZE ===" -ForegroundColor Cyan
    
    # Crescita del parco macchine nel tempo
    $growthQuery = @"
SELECT 
    date(collection_date) as day,
    COUNT(DISTINCT computer_name) as unique_computers,
    COUNT(*) as total_collections
FROM computers
WHERE collection_date >= date('now', '-30 days')
GROUP BY date(collection_date)
ORDER BY day
"@

    $growth = Invoke-SqliteQuery -DataSource $DatabasePath -Query $growthQuery
    
    Write-Host "`n📈 CRESCITA PARCO MACCHINE (ultimi 30 giorni):" -ForegroundColor Yellow
    $growth | ForEach-Object {
        Write-Host "  $($_.day): $($_.unique_computers) computer unici, $($_.total_collections) raccolte"
    }
    
    # Trend utilizzo dischi
    $diskTrendQuery = @"
SELECT 
    date(collection_date) as day,
    AVG(percent_used) as avg_usage,
    MAX(percent_used) as max_usage,
    COUNT(*) as disk_count
FROM disks
WHERE collection_date >= date('now', '-7 days')
GROUP BY date(collection_date)
ORDER BY day
"@

    $diskTrends = Invoke-SqliteQuery -DataSource $DatabasePath -Query $diskTrendQuery
    
    Write-Host "`n💿 TREND UTILIZZO DISCHI (ultimi 7 giorni):" -ForegroundColor Yellow
    $diskTrends | ForEach-Object {
        Write-Host "  $($_.day): Media $([math]::Round($_.avg_usage, 1))%, Max $([math]::Round($_.max_usage, 1))%, $($_.disk_count) dischi"
    }
}

# MAIN SCRIPT
Write-Host "=== MONITORIT SQLITE ANALYTICS ===" -ForegroundColor Cyan

if (!(Test-Path $DatabasePath)) {
    Write-Error "Database non trovato: $DatabasePath"
    exit 1
}

# Crea directory report se necessaria
if (!(Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# Inizializza SQLite
try {
    Initialize-SQLiteEnvironment -DatabasePath $DatabasePath | Out-Null
    Write-Host "✅ Connesso al database SQLite" -ForegroundColor Green
}
catch {
    Write-Error "Errore connessione database: $($_.Exception.Message)"
    exit 1
}

# Esegui il tipo di report richiesto
switch ($ReportType.ToLower()) {
    "summary" {
        Show-DatabaseSummary -DatabasePath $DatabasePath
        
        if ($ExportToHTML) {
            $stats = Get-DatabaseStatistics -DatabasePath $DatabasePath
            $reportData = @{ Stats = $stats }
            Export-ToHTML -Data $reportData -OutputPath $OutputPath -Title "Riepilogo Database MonitorIT"
        }
    }
    
    "detailed" {
        $inventory = Get-DetailedInventory -DatabasePath $DatabasePath -ComputerFilter $ComputerFilter -FromDate $FromDate -ToDate $ToDate
        
        if ($ExportToHTML -and $inventory) {
            $reportData = @{ Inventory = $inventory }
            Export-ToHTML -Data $reportData -OutputPath $OutputPath -Title "Inventario Dettagliato"
        }
    }
    
    "critical" {
        $alerts = Get-CriticalAlerts -DatabasePath $DatabasePath
        
        if ($ExportToHTML) {
            $reportData = @{ CriticalAlerts = $alerts }
            Export-ToHTML -Data $reportData -OutputPath $OutputPath -Title "Alert Critici"
        }
    }
    
    "trends" {
        Show-TrendAnalysis -DatabasePath $DatabasePath
    }
    
    "export" {
        Write-Host "Esportazione dati completi..." -ForegroundColor Yellow
        $fullInventory = Get-ComputerInventory -DatabasePath $DatabasePath -IncludeDisks
        
        if ($fullInventory) {
            $csvFile = Join-Path $OutputPath "MonitorIT_Export_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
            $fullInventory | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
            Write-Host "✅ Dati esportati in: $csvFile" -ForegroundColor Green
        }
    }
    
    default {
        Write-Host "Tipi di report disponibili:" -ForegroundColor Yellow
        Write-Host "  summary   - Riepilogo generale"
        Write-Host "  detailed  - Inventario dettagliato"
        Write-Host "  critical  - Alert critici"
        Write-Host "  trends    - Analisi tendenze"
        Write-Host "  export    - Esportazione completa"
    }
}

Write-Host "`n✅ Analisi completata!" -ForegroundColor Green