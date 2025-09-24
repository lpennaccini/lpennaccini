# Script di deployment SILENZIOSO per esecuzione nascosta sui client
# Utilizza questo script per distribuire ed eseguire la raccolta senza finestre visibili

param(
    [string[]]$ComputerNames = @(),
    [string]$NetworkShare = "\\server\shared\client_data",
    [string]$ScriptPath = ".\collect_client_info_silent.ps1",
    [PSCredential]$Credential,
    [switch]$UseTaskScheduler,        # Crea task schedulato invece di esecuzione immediata
    [string]$TaskTime = "02:00",      # Ora di esecuzione del task (02:00 AM)
    [switch]$HideWindows = $true      # Nasconde tutte le finestre
)

function Deploy-SilentScript {
    param([string]$ComputerName, [string]$ScriptContent)
    
    try {
        # Percorso nascosto per lo script
        $remoteScriptPath = "\\$ComputerName\C$\Windows\Temp\.monitorit_collection.ps1"
        
        # Crea directory nascosta se necessario
        $tempDir = "\\$ComputerName\C$\Windows\Temp"
        if (Test-Path $tempDir) {
            $ScriptContent | Out-File -FilePath $remoteScriptPath -Encoding UTF8 -Force
            
            # Nascondi il file
            $hiddenFile = Get-Item $remoteScriptPath -Force
            $hiddenFile.Attributes = "Hidden"
            
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

function Create-SilentTask {
    param([string]$ComputerName, [string]$NetworkShare, [string]$TaskTime)
    
    try {
        $taskAction = "PowerShell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Windows\Temp\.monitorit_collection.ps1 -DatabasePath '$NetworkShare' -OutputFormat 'CSV'"
        
        $taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>MonitorIT Client Data Collection</Description>
    <Author>MonitorIT System</Author>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>$(Get-Date -Format 'yyyy-MM-dd')T$($TaskTime):00</StartBoundary>
      <ScheduleByWeek>
        <WeeksInterval>1</WeeksInterval>
        <DaysOfWeek>
          <Monday />
        </DaysOfWeek>
      </ScheduleByWeek>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>true</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>true</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <ExecutionTimeLimit>PT30M</ExecutionTimeLimit>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>PowerShell.exe</Command>
      <Arguments>-WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\Windows\Temp\.monitorit_collection.ps1" -DatabasePath "$NetworkShare" -OutputFormat "CSV"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

        # Salva XML del task
        $taskXmlPath = "\\$ComputerName\C$\Windows\Temp\.monitorit_task.xml"
        $taskXml | Out-File -FilePath $taskXmlPath -Encoding UTF8
        
        # Crea il task tramite schtasks
        $createTaskCmd = "schtasks /create /tn `"MonitorIT_Collection`" /xml `"C:\Windows\Temp\.monitorit_task.xml`" /f"
        
        if ($Credential) {
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                param($cmd)
                cmd /c $cmd
            } -ArgumentList $createTaskCmd -Credential $Credential
        } else {
            $result = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                param($cmd)
                cmd /c $cmd
            } -ArgumentList $createTaskCmd
        }
        
        # Rimuovi file XML temporaneo
        Remove-Item $taskXmlPath -Force -ErrorAction SilentlyContinue
        
        return $true
    }
    catch {
        return $false
    }
}

function Execute-SilentCollection {
    param([string]$ComputerName, [string]$NetworkShare)
    
    try {
        $scriptBlock = {
            param($SharePath)
            
            # Esegui in modalità completamente nascosta
            $startInfo = New-Object System.Diagnostics.ProcessStartInfo
            $startInfo.FileName = "PowerShell.exe"
            $startInfo.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Windows\Temp\.monitorit_collection.ps1 -DatabasePath '$SharePath' -OutputFormat 'CSV'"
            $startInfo.UseShellExecute = $false
            $startInfo.CreateNoWindow = $true
            $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
            
            $process = [System.Diagnostics.Process]::Start($startInfo)
            $process.WaitForExit(300000)  # Timeout 5 minuti
            
            return $process.ExitCode
        }
        
        if ($Credential) {
            $exitCode = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList $NetworkShare -Credential $Credential
        } else {
            $exitCode = Invoke-Command -ComputerName $ComputerName -ScriptBlock $scriptBlock -ArgumentList $NetworkShare
        }
        
        return $exitCode -eq 0
    }
    catch {
        return $false
    }
}

# MAIN DEPLOYMENT SCRIPT SILENZIOSO
Write-Host "=== DEPLOYMENT SILENZIOSO MONITORIT ===" -ForegroundColor Cyan

if (!(Test-Path $ScriptPath)) {
    Write-Error "Script non trovato: $ScriptPath"
    exit 1
}

$scriptContent = Get-Content $ScriptPath -Raw

if ($ComputerNames.Count -eq 0) {
    Write-Host "Modalità interattiva - Inserisci i nomi dei computer:"
    $input = Read-Host "Computer (separati da virgola) o 'localhost'"
    if ($input -eq "localhost") {
        $ComputerNames = @($env:COMPUTERNAME)
    } else {
        $ComputerNames = $input -split ',' | ForEach-Object { $_.Trim() }
    }
}

$successCount = 0
$totalCount = $ComputerNames.Count

Write-Host "`nTarget: $($ComputerNames -join ', ')" -ForegroundColor Yellow
Write-Host "Database: $NetworkShare" -ForegroundColor Yellow
Write-Host "Modalità: $(if($UseTaskScheduler){'Task Schedulato'}else{'Esecuzione Immediata'})" -ForegroundColor Yellow
Write-Host "Visibilità: NASCOSTO agli utenti" -ForegroundColor Green

foreach ($computer in $ComputerNames) {
    Write-Host "`n--- $computer ---" -ForegroundColor Cyan
    
    # Test connessione rapido
    if (!(Test-Connection -ComputerName $computer -Count 1 -Quiet)) {
        Write-Host "✗ Non raggiungibile" -ForegroundColor Red
        continue
    }
    
    # Per localhost
    if ($computer -eq $env:COMPUTERNAME -or $computer -eq "localhost") {
        Write-Host "Esecuzione locale nascosta..."
        try {
            if ($HideWindows) {
                # Esecuzione nascosta locale
                $startInfo = New-Object System.Diagnostics.ProcessStartInfo
                $startInfo.FileName = "PowerShell.exe"
                $startInfo.Arguments = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`" -DatabasePath `"$NetworkShare`" -OutputFormat `"CSV`""
                $startInfo.UseShellExecute = $false
                $startInfo.CreateNoWindow = $true
                $startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
                
                $process = [System.Diagnostics.Process]::Start($startInfo)
                $process.WaitForExit(60000)  # Timeout 1 minuto
                
                if ($process.ExitCode -eq 0) {
                    $successCount++
                    Write-Host "✓ Completato" -ForegroundColor Green
                } else {
                    Write-Host "✗ Errore (Exit Code: $($process.ExitCode))" -ForegroundColor Red
                }
            } else {
                & $ScriptPath -DatabasePath $NetworkShare -OutputFormat "CSV"
                $successCount++
                Write-Host "✓ Completato" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "✗ Errore: $($_.Exception.Message)" -ForegroundColor Red
        }
        continue
    }
    
    # Deploy script
    $deployed = Deploy-SilentScript -ComputerName $computer -ScriptContent $scriptContent
    if (!$deployed) {
        Write-Host "✗ Errore deploy" -ForegroundColor Red
        continue
    }
    Write-Host "✓ Script deployato" -ForegroundColor Green
    
    # Crea task schedulato o esegui immediatamente
    if ($UseTaskScheduler) {
        $taskCreated = Create-SilentTask -ComputerName $computer -NetworkShare $NetworkShare -TaskTime $TaskTime
        if ($taskCreated) {
            $successCount++
            Write-Host "✓ Task schedulato creato" -ForegroundColor Green
        } else {
            Write-Host "✗ Errore creazione task" -ForegroundColor Red
        }
    } else {
        $executed = Execute-SilentCollection -ComputerName $computer -NetworkShare $NetworkShare
        if ($executed) {
            $successCount++
            Write-Host "✓ Raccolta completata" -ForegroundColor Green
        } else {
            Write-Host "✗ Errore esecuzione" -ForegroundColor Red
        }
    }
}

Write-Host "`n=== RIEPILOGO DEPLOYMENT SILENZIOSO ===" -ForegroundColor Cyan
Write-Host "Computer elaborati: $totalCount"
Write-Host "Successi: $successCount" -ForegroundColor Green
Write-Host "Fallimenti: $($totalCount - $successCount)" -ForegroundColor Red

if ($UseTaskScheduler -and $successCount -gt 0) {
    Write-Host "`nTask schedulati per esecuzione alle $TaskTime ogni lunedì" -ForegroundColor Yellow
    Write-Host "I dati saranno raccolti automaticamente in: $NetworkShare" -ForegroundColor Yellow
} elseif ($successCount -gt 0) {
    Write-Host "`nRaccolta immediata completata in modalità silenziosa" -ForegroundColor Yellow
    Write-Host "Dati disponibili in: $NetworkShare" -ForegroundColor Yellow
}

Write-Host "`n✅ NESSUNA FINESTRA SARÀ VISIBILE AGLI UTENTI" -ForegroundColor Green