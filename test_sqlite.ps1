# Script PowerShell SEMPLICE per test SQLite - MonitorIT
# Versione: 3.0 - Test SQLite
# Creato il: 23 settembre 2025

param(
    [string]$DatabasePath = ".\test_data\inventory.db",
    [switch]$SilentMode = $false
)

# Test semplice per verificare che PSSQLite funzioni
try {
    Write-Host "Test modulo PSSQLite..." -ForegroundColor Yellow
    Import-Module PSSQLite -Force
    
    # Crea directory se non esiste
    $dbDir = Split-Path $DatabasePath -Parent
    if (!(Test-Path $dbDir)) {
        New-Item -ItemType Directory -Path $dbDir -Force | Out-Null
    }
    
    # Test query di base
    $testQuery = "SELECT 'Hello SQLite' as test_message"
    $result = Invoke-SqliteQuery -DataSource $DatabasePath -Query $testQuery
    
    Write-Host "✅ SQLite funziona! Risultato: $($result.test_message)" -ForegroundColor Green
    
    # Crea tabella di test
    $createTable = @"
CREATE TABLE IF NOT EXISTS test_computers (
    id INTEGER PRIMARY KEY,
    computer_name TEXT,
    test_date TEXT
);
"@
    
    Invoke-SqliteQuery -DataSource $DatabasePath -Query $createTable
    
    # Inserisci dato di test
    $insertData = "INSERT INTO test_computers (computer_name, test_date) VALUES ('$env:COMPUTERNAME', '$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")')"
    Invoke-SqliteQuery -DataSource $DatabasePath -Query $insertData
    
    # Leggi i dati
    $readData = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT * FROM test_computers"
    
    Write-Host "✅ Dati nel database:" -ForegroundColor Green
    $readData | Format-Table -AutoSize
    
    Write-Host "✅ Test SQLite completato con successo!" -ForegroundColor Green
}
catch {
    Write-Host "❌ Errore SQLite: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Verifica che il modulo PSSQLite sia installato correttamente" -ForegroundColor Yellow
}