# Modulo PowerShell per gestione database SQLite - MonitorIT
# Versione: 3.0 - SQLite Integration
# Creato il: 23 settembre 2025

# Importa il modulo SQLite se disponibile, altrimenti usa System.Data.SQLite
function Initialize-SQLiteEnvironment {
    param([string]$DatabasePath)
    
    try {
        # Prova a importare il modulo PSSQLite se disponibile
        if (Get-Module -ListAvailable -Name PSSQLite) {
            Import-Module PSSQLite -Force
            return "PSSQLite"
        }
        
        # Fallback a System.Data.SQLite .NET
        Add-Type -Path "$PSScriptRoot\System.Data.SQLite.dll" -ErrorAction SilentlyContinue
        return "System.Data.SQLite"
    }
    catch {
        Write-Warning "SQLite non disponibile. Installazione automatica..."
        Install-SQLiteModule
        return "PSSQLite"
    }
}

function Install-SQLiteModule {
    try {
        Write-Host "Installazione modulo PSSQLite..." -ForegroundColor Yellow
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
        Install-Module -Name PSSQLite -Force -Scope CurrentUser -AllowClobber
        Import-Module PSSQLite -Force
        Write-Host "✓ PSSQLite installato con successo" -ForegroundColor Green
    }
    catch {
        throw "Impossibile installare PSSQLite: $($_.Exception.Message)"
    }
}

function Initialize-Database {
    param([string]$DatabasePath)
    
    try {
        # Crea la directory se non esiste
        $dbDir = Split-Path $DatabasePath -Parent
        if (!(Test-Path $dbDir)) {
            New-Item -ItemType Directory -Path $dbDir -Force | Out-Null
        }
        
        # Crea le tabelle se il database non esiste
        if (!(Test-Path $DatabasePath)) {
            Write-Host "Creazione nuovo database SQLite: $DatabasePath" -ForegroundColor Yellow
            New-Item -ItemType File -Path $DatabasePath -Force | Out-Null
        }
        
        # Crea le tabelle
        $createTablesSQL = @"
-- Tabella principale computer
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
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tabella dischi
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

-- Tabella log eventi
CREATE TABLE IF NOT EXISTS collection_log (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    computer_name TEXT NOT NULL,
    collection_date TEXT NOT NULL,
    status TEXT NOT NULL,
    message TEXT,
    error_details TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Indici per performance
CREATE INDEX IF NOT EXISTS idx_computers_name ON computers (computer_name);
CREATE INDEX IF NOT EXISTS idx_computers_date ON computers (collection_date);
CREATE INDEX IF NOT EXISTS idx_disks_computer ON disks (computer_id);
CREATE INDEX IF NOT EXISTS idx_log_computer ON collection_log (computer_name);
CREATE INDEX IF NOT EXISTS idx_log_date ON collection_log (collection_date);

-- View per report completi
CREATE VIEW IF NOT EXISTS computer_summary AS
SELECT 
    c.computer_name,
    c.collection_date,
    c.user_name,
    c.ip_address,
    c.os_name,
    c.manufacturer,
    c.model,
    c.total_ram_gb,
    COUNT(d.id) as disk_count,
    SUM(d.total_size_gb) as total_disk_space_gb,
    SUM(d.free_space_gb) as total_free_space_gb,
    ROUND(AVG(d.percent_used), 1) as avg_disk_usage_percent
FROM computers c
LEFT JOIN disks d ON c.id = d.computer_id
GROUP BY c.id, c.computer_name, c.collection_date;
"@

        Invoke-SqliteQuery -DataSource $DatabasePath -Query $createTablesSQL
        Write-Host "✓ Database SQLite inizializzato" -ForegroundColor Green
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
        # Inizializza il database se necessario
        if (!(Initialize-Database -DatabasePath $DatabasePath)) {
            throw "Impossibile inizializzare il database"
        }
        
        # Verifica se il computer esiste già per questa data
        $existingQuery = @"
SELECT id FROM computers 
WHERE computer_name = '$($ComputerData.ComputerName)' 
AND date(collection_date) = date('$($ComputerData.CollectionDate)')
"@
        
        $existingRecord = Invoke-SqliteQuery -DataSource $DatabasePath -Query $existingQuery
        
        if ($existingRecord) {
            # Aggiorna record esistente
            $computerId = $existingRecord.id
            $updateQuery = @"
UPDATE computers SET
    user_name = '$($ComputerData.UserName)',
    domain_name = '$($ComputerData.Domain)',
    ip_address = '$($ComputerData.IPAddress)',
    mac_address = '$($ComputerData.MACAddress)',
    os_name = '$($ComputerData.OSName)',
    os_version = '$($ComputerData.OSVersion)',
    os_architecture = '$($ComputerData.OSArchitecture)',
    manufacturer = '$($ComputerData.Manufacturer)',
    model = '$($ComputerData.Model)',
    system_type = '$($ComputerData.SystemType)',
    total_ram_gb = $($ComputerData.TotalRAM_GB),
    serial_number = '$($ComputerData.SerialNumber)',
    updated_at = CURRENT_TIMESTAMP
WHERE id = $computerId
"@
            Invoke-SqliteQuery -DataSource $DatabasePath -Query $updateQuery
            
            # Rimuovi dischi esistenti per questo computer/data
            $deleteDisksQuery = "DELETE FROM disks WHERE computer_id = $computerId"
            Invoke-SqliteQuery -DataSource $DatabasePath -Query $deleteDisksQuery
            
            Write-Host "✓ Record aggiornato per $($ComputerData.ComputerName)" -ForegroundColor Yellow
        }
        else {
            # Inserisci nuovo record
            $insertQuery = @"
INSERT INTO computers (
    computer_name, collection_date, user_name, domain_name, ip_address, 
    mac_address, os_name, os_version, os_architecture, manufacturer, 
    model, system_type, total_ram_gb, serial_number
) VALUES (
    '$($ComputerData.ComputerName)', '$($ComputerData.CollectionDate)', 
    '$($ComputerData.UserName)', '$($ComputerData.Domain)', '$($ComputerData.IPAddress)',
    '$($ComputerData.MACAddress)', '$($ComputerData.OSName)', '$($ComputerData.OSVersion)',
    '$($ComputerData.OSArchitecture)', '$($ComputerData.Manufacturer)', '$($ComputerData.Model)',
    '$($ComputerData.SystemType)', $($ComputerData.TotalRAM_GB), '$($ComputerData.SerialNumber)'
)
"@
            Invoke-SqliteQuery -DataSource $DatabasePath -Query $insertQuery
            
            # Ottieni l'ID del record appena inserito
            $computerId = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT last_insert_rowid() as id"
            $computerId = $computerId.id
            
            Write-Host "✓ Nuovo record creato per $($ComputerData.ComputerName)" -ForegroundColor Green
        }
        
        # Inserisci informazioni dischi
        foreach ($disk in $ComputerData.Disks) {
            $diskQuery = @"
INSERT INTO disks (
    computer_id, drive_letter, volume_label, total_size_gb, 
    free_space_gb, used_space_gb, percent_used, file_system, collection_date
) VALUES (
    $computerId, '$($disk.Drive)', '$($disk.Label)', $($disk.TotalSize_GB),
    $($disk.FreeSpace_GB), $($disk.UsedSpace_GB), $($disk.PercentUsed),
    '$($disk.FileSystem)', '$($ComputerData.CollectionDate)'
)
"@
            Invoke-SqliteQuery -DataSource $DatabasePath -Query $diskQuery
        }
        
        # Log successo
        $logQuery = @"
INSERT INTO collection_log (computer_name, collection_date, status, message)
VALUES ('$($ComputerData.ComputerName)', '$($ComputerData.CollectionDate)', 'SUCCESS', 'Dati salvati con successo')
"@
        Invoke-SqliteQuery -DataSource $DatabasePath -Query $logQuery
        
        return $true
    }
    catch {
        # Log errore
        $errorQuery = @"
INSERT INTO collection_log (computer_name, collection_date, status, message, error_details)
VALUES ('$($ComputerData.ComputerName)', '$($ComputerData.CollectionDate)', 'ERROR', 'Errore salvataggio dati', '$($_.Exception.Message)')
"@
        try {
            Invoke-SqliteQuery -DataSource $DatabasePath -Query $errorQuery
        } catch {}
        
        Write-Error "Errore salvataggio dati: $($_.Exception.Message)"
        return $false
    }
}

function Get-ComputerInventory {
    param(
        [string]$DatabasePath,
        [string]$ComputerName = "",
        [string]$FromDate = "",
        [string]$ToDate = "",
        [switch]$IncludeDisks
    )
    
    try {
        $whereClause = "WHERE 1=1"
        
        if ($ComputerName -ne "") {
            $whereClause += " AND computer_name LIKE '%$ComputerName%'"
        }
        
        if ($FromDate -ne "") {
            $whereClause += " AND date(collection_date) >= date('$FromDate')"
        }
        
        if ($ToDate -ne "") {
            $whereClause += " AND date(collection_date) <= date('$ToDate')"
        }
        
        $query = "SELECT * FROM computer_summary $whereClause ORDER BY collection_date DESC"
        
        $results = Invoke-SqliteQuery -DataSource $DatabasePath -Query $query
        
        if ($IncludeDisks) {
            foreach ($computer in $results) {
                $diskQuery = @"
SELECT * FROM disks d
JOIN computers c ON d.computer_id = c.id
WHERE c.computer_name = '$($computer.computer_name)' 
AND date(d.collection_date) = date('$($computer.collection_date)')
"@
                $computer | Add-Member -NotePropertyName "DiskDetails" -NotePropertyValue (Invoke-SqliteQuery -DataSource $DatabasePath -Query $diskQuery)
            }
        }
        
        return $results
    }
    catch {
        Write-Error "Errore lettura inventario: $($_.Exception.Message)"
        return $null
    }
}

function Get-DatabaseStatistics {
    param([string]$DatabasePath)
    
    try {
        $stats = @{}
        
        # Statistiche generali
        $totalComputers = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(DISTINCT computer_name) as count FROM computers"
        $stats.TotalComputers = $totalComputers.count
        
        $totalRecords = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT COUNT(*) as count FROM computers"
        $stats.TotalRecords = $totalRecords.count
        
        $lastCollection = Invoke-SqliteQuery -DataSource $DatabasePath -Query "SELECT MAX(collection_date) as last_date FROM computers"
        $stats.LastCollection = $lastCollection.last_date
        
        # Statistiche OS
        $osStats = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT os_name, COUNT(*) as count 
FROM (
    SELECT computer_name, os_name, MAX(collection_date) as last_date
    FROM computers 
    GROUP BY computer_name
) 
GROUP BY os_name 
ORDER BY count DESC
"@
        $stats.OSDistribution = $osStats
        
        # Statistiche produttori
        $manufStats = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT manufacturer, COUNT(*) as count 
FROM (
    SELECT computer_name, manufacturer, MAX(collection_date) as last_date
    FROM computers 
    GROUP BY computer_name
) 
GROUP BY manufacturer 
ORDER BY count DESC
"@
        $stats.ManufacturerDistribution = $manufStats
        
        # Dischi con utilizzo critico
        $criticalDisks = Invoke-SqliteQuery -DataSource $DatabasePath -Query @"
SELECT c.computer_name, d.drive_letter, d.percent_used, d.free_space_gb
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
        $stats.CriticalDisks = $criticalDisks
        
        return $stats
    }
    catch {
        Write-Error "Errore statistiche database: $($_.Exception.Message)"
        return $null
    }
}

# Esporta le funzioni
Export-ModuleMember -Function Initialize-SQLiteEnvironment, Initialize-Database, Save-ComputerData, Get-ComputerInventory, Get-DatabaseStatistics