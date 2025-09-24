# Modulo SQLite Manager semplificato per MonitorIT
# Versione: 3.0 - Working Version

function Initialize-Database {
    param([string]$DatabasePath)
    
    try {
        Import-Module PSSQLite -Force
        
        # Crea la directory se non esiste
        $dbDir = Split-Path $DatabasePath -Parent
        if (!(Test-Path $dbDir)) {
            New-Item -ItemType Directory -Path $dbDir -Force | Out-Null
        }
        
        # Crea le tabelle se il database non esiste o è vuoto
        $createTablesSQL = @"
CREATE TABLE IF NOT EXISTS computers (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    computer_name TEXT NOT NULL,
    collection_date TEXT NOT NULL,
    user_name TEXT,
    domain_name TEXT,
    ip_address TEXT,
    mac_address TEXT,
    os_name TEXT,
    os_version TEXT,
    os_architecture TEXT,
    manufacturer TEXT,
    model TEXT,
    system_type TEXT,
    total_ram_gb REAL,
    serial_number TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS disks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    computer_id INTEGER,
    drive_letter TEXT NOT NULL,
    volume_label TEXT,
    total_size_gb REAL,
    free_space_gb REAL,
    used_space_gb REAL,
    percent_used REAL,
    file_system TEXT,
    collection_date TEXT,
    FOREIGN KEY (computer_id) REFERENCES computers (id)
);

CREATE INDEX IF NOT EXISTS idx_computers_name ON computers (computer_name);
CREATE INDEX IF NOT EXISTS idx_computers_date ON computers (collection_date);
"@

        Invoke-SqliteQuery -DataSource $DatabasePath -Query $createTablesSQL
        return $true
    }
    catch {
        Write-Error "Errore inizializzazione database: $($_.Exception.Message)"
        return $false
    }
}

function Save-ComputerData {
    param(
        [string]$DatabasePath,
        [PSCustomObject]$ComputerData
    )
    
    try {
        # Inizializza il database
        if (!(Initialize-Database -DatabasePath $DatabasePath)) {
            throw "Impossibile inizializzare il database"
        }
        
        # Escape delle virgolette singole per SQL
        $computerName = $ComputerData.ComputerName -replace "'", "''"
        $userName = $ComputerData.UserName -replace "'", "''"
        $domain = $ComputerData.Domain -replace "'", "''"
        $osName = $ComputerData.OSName -replace "'", "''"
        $manufacturer = $ComputerData.Manufacturer -replace "'", "''"
        $model = $ComputerData.Model -replace "'", "''"
        
        # Verifica se il computer esiste già per oggi
        $existingQuery = @"
SELECT id FROM computers 
WHERE computer_name = '$computerName' 
AND date(collection_date) = date('$($ComputerData.CollectionDate)')
"@
        
        $existingRecord = Invoke-SqliteQuery -DataSource $DatabasePath -Query $existingQuery
        
        if ($existingRecord) {
            # Aggiorna record esistente
            $computerId = $existingRecord.id
            $updateQuery = @"
UPDATE computers SET
    user_name = '$userName',
    domain_name = '$domain',
    ip_address = '$($ComputerData.IPAddress)',
    mac_address = '$($ComputerData.MACAddress)',
    os_name = '$osName',
    os_version = '$($ComputerData.OSVersion)',
    os_architecture = '$($ComputerData.OSArchitecture)',
    manufacturer = '$manufacturer',
    model = '$model',
    system_type = '$($ComputerData.SystemType)',
    total_ram_gb = $($ComputerData.TotalRAM_GB),
    serial_number = '$($ComputerData.SerialNumber)'
WHERE id = $computerId
"@
            Invoke-SqliteQuery -DataSource $DatabasePath -Query $updateQuery
            
            # Rimuovi dischi esistenti
            Invoke-SqliteQuery -DataSource $DatabasePath -Query "DELETE FROM disks WHERE computer_id = $computerId"
        }
        else {
            # Inserisci nuovo record
            $insertQuery = @"
INSERT INTO computers (
    computer_name, collection_date, user_name, domain_name, ip_address, 
    mac_address, os_name, os_version, os_architecture, manufacturer, 
    model, system_type, total_ram_gb, serial_number
) VALUES (
    '$computerName', '$($ComputerData.CollectionDate)', 
    '$userName', '$domain', '$($ComputerData.IPAddress)',
    '$($ComputerData.MACAddress)', '$osName', '$($ComputerData.OSVersion)',
    '$($ComputerData.OSArchitecture)', '$manufacturer', '$model',
    '$($ComputerData.SystemType)', $($ComputerData.TotalRAM_GB), '$($ComputerData.SerialNumber)'
)
"@
            Invoke-SqliteQuery -DataSource $DatabasePath -Query $insertQuery
            
            # Ottieni l'ID del record appena inserito
            $computerId = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT last_insert_rowid() as id").id
        }
        
        # Inserisci informazioni dischi
        foreach ($disk in $ComputerData.Disks) {
            $volumeLabel = $disk.Label -replace "'", "''"
            $diskQuery = @"
INSERT INTO disks (
    computer_id, drive_letter, volume_label, total_size_gb, 
    free_space_gb, used_space_gb, percent_used, file_system, collection_date
) VALUES (
    $computerId, '$($disk.Drive)', '$volumeLabel', $($disk.TotalSize_GB),
    $($disk.FreeSpace_GB), $($disk.UsedSpace_GB), $($disk.PercentUsed),
    '$($disk.FileSystem)', '$($ComputerData.CollectionDate)'
)
"@
            Invoke-SqliteQuery -DataSource $DatabasePath -Query $diskQuery
        }
        
        return $true
    }
    catch {
        Write-Error "Errore salvataggio dati: $($_.Exception.Message)"
        return $false
    }
}

function Get-DatabaseSummary {
    param([string]$DatabasePath)
    
    try {
        $stats = @{}
        
        # Computer totali
        $totalComputers = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(DISTINCT computer_name) as count FROM computers").count
        $stats.TotalComputers = $totalComputers
        
        # Ultima raccolta
        $lastCollection = (Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT MAX(collection_date) as last_date FROM computers").last_date
        $stats.LastCollection = $lastCollection
        
        # Distribuzione OS
        $osStats = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT os_name, COUNT(DISTINCT computer_name) as count 
FROM computers 
GROUP BY os_name 
ORDER BY count DESC
"@
        $stats.OSDistribution = $osStats
        
        # Dischi critici
        $criticalDisks = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT c.computer_name, d.drive_letter, d.percent_used, d.free_space_gb
FROM disks d
JOIN computers c ON d.computer_id = c.id
WHERE d.percent_used > 80
ORDER BY d.percent_used DESC
"@
        $stats.CriticalDisks = $criticalDisks
        
        return $stats
    }
    catch {
        Write-Error "Errore statistiche database: $($_.Exception.Message)"
        return $null
    }
}

# Esporta le funzioni
Export-ModuleMember -Function Initialize-Database, Save-ComputerData, Get-DatabaseSummary