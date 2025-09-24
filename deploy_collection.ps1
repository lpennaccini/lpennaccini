# Script di deployment per distribuzione client
# Utilizza questo script per distribuire e eseguire la raccolta dati sui client della rete

param(
    [string[]]$ComputerNames = @(),           # Lista PC target
    [string]$NetworkShare = "\\server\shared\client_data",  # Percorso condiviso
    [string]$ScriptPath = ".\collect_client_info.ps1",      # Percorso script da distribuire
    [PSCredential]$Credential,                              # Credenziali per accesso remoto
    [switch]$TestConnection                                 # Test connettività prima dell'esecuzione
)

function Test-RemoteConnection {
    param([string]$ComputerName)
    
    if (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet) {
        Write-Host "✓ $ComputerName è raggiungibile" -ForegroundColor Green
        return $true
    } else {
        Write-Host "✗ $ComputerName non è raggiungibile" -ForegroundColor Red
        return $false
    }
}

function Deploy-ClientScript {
    param([string]$ComputerName, [string]$ScriptContent)
    
    try {
        $remoteScriptPath = "\\$ComputerName\C$\temp\collect_client_info.ps1"
        
        # Crea directory temp se non esiste
        $tempDir = "\\$ComputerName\C$\temp"
        if (!(Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        
        # Copia script
        $ScriptContent | Out-File -FilePath $remoteScriptPath -Encoding UTF8
        
        Write-Host "✓ Script copiato su $ComputerName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ Errore nella copia su $ComputerName`: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Execute-RemoteCollection {
    param([string]$ComputerName, [string]$NetworkShare)
    
    try {
        $scriptBlock = {
            param($SharePath)
            Set-Location C:\temp
            .\collect_client_info.ps1 -DatabasePath $SharePath -OutputFormat "CSV"
        }
        
        if ($Credential) {
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList $NetworkShare -Credential $Credential
        } else {
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList $NetworkShare
        }
        
        Write-Host "✓ Raccolta completata su $ComputerName" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host "✗ Errore nell'esecuzione su $ComputerName`: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# MAIN DEPLOYMENT SCRIPT
Write-Host "=== DEPLOYMENT SCRIPT RACCOLTA CLIENT ===" -ForegroundColor Cyan

# Leggi il contenuto dello script da distribuire
if (!(Test-Path $ScriptPath)) {
    Write-Error "Script non trovato: $ScriptPath"
    exit 1
}

$scriptContent = Get-Content $ScriptPath -Raw

# Se non sono specificati computer, chiedi input
if ($ComputerNames.Count -eq 0) {
    Write-Host "Inserisci i nomi dei computer (separati da virgola) o 'localhost' per il PC corrente:"
    $input = Read-Host
    if ($input -eq "localhost") {
        $ComputerNames = @($env:COMPUTERNAME)
    } else {
        $ComputerNames = $input -split ',' | ForEach-Object { $_.Trim() }
    }
}

$successCount = 0
$totalCount = $ComputerNames.Count

Write-Host "`nTarget computers: $($ComputerNames -join ', ')" -ForegroundColor Yellow
Write-Host "Network share: $NetworkShare" -ForegroundColor Yellow

foreach ($computer in $ComputerNames) {
    Write-Host "`n--- Elaborazione $computer ---" -ForegroundColor Cyan
    
    # Test connessione se richiesto
    if ($TestConnection) {
        if (!(Test-RemoteConnection -ComputerName $computer)) {
            continue
        }
    }
    
    # Per localhost, esegui direttamente
    if ($computer -eq $env:COMPUTERNAME -or $computer -eq "localhost") {
        Write-Host "Esecuzione locale..."
        try {
            & $ScriptPath -DatabasePath $NetworkShare -OutputFormat "CSV"
            $successCount++
            Write-Host "✓ Raccolta locale completata" -ForegroundColor Green
        }
        catch {
            Write-Host "✗ Errore nell'esecuzione locale: $($_.Exception.Message)" -ForegroundColor Red
        }
        continue
    }
    
    # Per computer remoti
    $deployed = Deploy-ClientScript -ComputerName $computer -ScriptContent $scriptContent
    if ($deployed) {
        $executed = Execute-RemoteCollection -ComputerName $computer -NetworkShare $NetworkShare
        if ($executed) {
            $successCount++
        }
    }
}

Write-Host "`n=== RIEPILOGO DEPLOYMENT ===" -ForegroundColor Cyan
Write-Host "Computer elaborati: $totalCount"
Write-Host "Successi: $successCount" -ForegroundColor Green
Write-Host "Fallimenti: $($totalCount - $successCount)" -ForegroundColor Red

if ($successCount -gt 0) {
    Write-Host "`nI dati raccolti dovrebbero essere disponibili in: $NetworkShare" -ForegroundColor Yellow
}