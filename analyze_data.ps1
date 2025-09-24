# Script per analizzare i dati raccolti dai client
# Genera report e statistiche dall'inventario

param(
    [string]$DataPath = "\\server\shared\client_data\client_inventory.csv",
    [string]$ReportPath = ".\reports",
    [switch]$GenerateHTML,
    [switch]$ExportToExcel
)

function Import-ClientData {
    param([string]$FilePath)
    
    if (!(Test-Path $FilePath)) {
        Write-Error "File dati non trovato: $FilePath"
        return $null
    }
    
    try {
        $data = Import-Csv $FilePath -Encoding UTF8
        
        # Converti le informazioni dischi da JSON
        foreach ($record in $data) {
            if ($record.DisksInfo) {
                $record | Add-Member -NotePropertyName "ParsedDisks" -NotePropertyValue ($record.DisksInfo | ConvertFrom-Json)
            }
        }
        
        return $data
    }
    catch {
        Write-Error "Errore nell'importazione dati: $($_.Exception.Message)"
        return $null
    }
}

function Generate-Summary {
    param($Data)
    
    $summary = [PSCustomObject]@{
        TotalComputers = $Data.Count
        UniqueUsers = ($Data | Select-Object -ExpandProperty UserName -Unique).Count
        UniqueDomains = ($Data | Select-Object -ExpandProperty Domain -Unique).Count
        OSDistribution = $Data | Group-Object OSName | Sort-Object Count -Descending
        ManufacturerDistribution = $Data | Group-Object Manufacturer | Sort-Object Count -Descending
        AvgRAM = [math]::Round(($Data | Measure-Object TotalRAM_GB -Average).Average, 2)
        TotalRAM = [math]::Round(($Data | Measure-Object TotalRAM_GB -Sum).Sum, 2)
        LastCollection = ($Data | Measure-Object CollectionDate -Maximum).Maximum
        FirstCollection = ($Data | Measure-Object CollectionDate -Minimum).Minimum
    }
    
    return $summary
}

function Generate-TextReport {
    param($Data, $Summary, $OutputPath)
    
    $report = @"
=== REPORT INVENTARIO CLIENT ===
Generato il: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")

=== STATISTICHE GENERALI ===
Totale computer: $($Summary.TotalComputers)
Utenti univoci: $($Summary.UniqueUsers)
Domini: $($Summary.UniqueDomains)
RAM media per PC: $($Summary.AvgRAM) GB
RAM totale rete: $($Summary.TotalRAM) GB
Prima raccolta: $($Summary.FirstCollection)
Ultima raccolta: $($Summary.LastCollection)

=== DISTRIBUZIONE SISTEMI OPERATIVI ===
$($Summary.OSDistribution | ForEach-Object { "$($_.Name): $($_.Count) PC" } | Out-String)

=== DISTRIBUZIONE PRODUTTORI ===
$($Summary.ManufacturerDistribution | ForEach-Object { "$($_.Name): $($_.Count) PC" } | Out-String)

=== DETTAGLIO COMPUTER ===
$($Data | Select-Object ComputerName, UserName, IPAddress, OSName, TotalRAM_GB, Manufacturer, Model | Format-Table -AutoSize | Out-String)

=== ANALISI DISCHI ===
$(
    $diskAnalysis = @()
    foreach ($computer in $Data) {
        if ($computer.ParsedDisks) {
            foreach ($disk in $computer.ParsedDisks) {
                $diskAnalysis += [PSCustomObject]@{
                    Computer = $computer.ComputerName
                    Drive = $disk.Drive
                    TotalGB = $disk.TotalSize_GB
                    UsedPercent = $disk.PercentUsed
                    FreeGB = $disk.FreeSpace_GB
                }
            }
        }
    }
    
    if ($diskAnalysis.Count -gt 0) {
        "Spazio disco totale: $([math]::Round(($diskAnalysis | Measure-Object TotalGB -Sum).Sum, 2)) GB`n"
        "Dischi con utilizzo > 80%:`n"
        $highUsage = $diskAnalysis | Where-Object { $_.UsedPercent -gt 80 }
        if ($highUsage) {
            $highUsage | Format-Table -AutoSize | Out-String
        } else {
            "Nessun disco con utilizzo critico`n"
        }
    }
)

=== FINE REPORT ===
"@

    $report | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "Report testuale salvato: $OutputPath" -ForegroundColor Green
}

function Generate-HTMLReport {
    param($Data, $Summary, $OutputPath)
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Report Inventario Client</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .header { background-color: #4CAF50; color: white; padding: 10px; text-align: center; }
        .section { margin: 20px 0; padding: 10px; border: 1px solid #ddd; }
        .stats { display: flex; flex-wrap: wrap; gap: 20px; }
        .stat-box { background-color: #f5f5f5; padding: 15px; border-radius: 5px; min-width: 200px; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .warning { background-color: #ffebee; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Report Inventario Client</h1>
        <p>Generato il: $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")</p>
    </div>
    
    <div class="section">
        <h2>Statistiche Generali</h2>
        <div class="stats">
            <div class="stat-box"><strong>Totale Computer:</strong> $($Summary.TotalComputers)</div>
            <div class="stat-box"><strong>Utenti Univoci:</strong> $($Summary.UniqueUsers)</div>
            <div class="stat-box"><strong>RAM Media:</strong> $($Summary.AvgRAM) GB</div>
            <div class="stat-box"><strong>RAM Totale:</strong> $($Summary.TotalRAM) GB</div>
        </div>
    </div>
    
    <div class="section">
        <h2>Dettaglio Computer</h2>
        <table>
            <tr>
                <th>Computer</th>
                <th>Utente</th>
                <th>IP</th>
                <th>Sistema Operativo</th>
                <th>RAM (GB)</th>
                <th>Produttore</th>
                <th>Modello</th>
            </tr>
            $($Data | ForEach-Object {
                "<tr>
                    <td>$($_.ComputerName)</td>
                    <td>$($_.UserName)</td>
                    <td>$($_.IPAddress)</td>
                    <td>$($_.OSName)</td>
                    <td>$($_.TotalRAM_GB)</td>
                    <td>$($_.Manufacturer)</td>
                    <td>$($_.Model)</td>
                </tr>"
            } | Out-String)
        </table>
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "Report HTML salvato: $OutputPath" -ForegroundColor Green
}

# MAIN ANALYSIS SCRIPT
Write-Host "=== ANALISI DATI CLIENT ===" -ForegroundColor Cyan

# Importa dati
Write-Host "Importazione dati da: $DataPath"
$clientData = Import-ClientData -FilePath $DataPath

if ($clientData -eq $null -or $clientData.Count -eq 0) {
    Write-Error "Nessun dato da analizzare"
    exit 1
}

Write-Host "Dati importati: $($clientData.Count) record" -ForegroundColor Green

# Genera statistiche
$summary = Generate-Summary -Data $clientData

# Crea directory report
if (!(Test-Path $ReportPath)) {
    New-Item -ItemType Directory -Path $ReportPath -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Genera report testuale
$textReportPath = Join-Path $ReportPath "inventory_report_$timestamp.txt"
Generate-TextReport -Data $clientData -Summary $summary -OutputPath $textReportPath

# Genera report HTML se richiesto
if ($GenerateHTML) {
    $htmlReportPath = Join-Path $ReportPath "inventory_report_$timestamp.html"
    Generate-HTMLReport -Data $clientData -Summary $summary -OutputPath $htmlReportPath
}

# Esporta dati per Excel se richiesto
if ($ExportToExcel) {
    $excelPath = Join-Path $ReportPath "inventory_data_$timestamp.csv"
    $clientData | Export-Csv -Path $excelPath -NoTypeInformation -Encoding UTF8
    Write-Host "Dati esportati per Excel: $excelPath" -ForegroundColor Green
}

Write-Host "`nAnalisi completata! Report disponibili in: $ReportPath" -ForegroundColor Green