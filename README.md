# MonitorIT 🖥️

**Sistema completo di monitoraggio per computer Windows in rete aziendale**

Toolkit PowerShell moderno con dashboard web per raccogliere, archiviare e visualizzare informazioni hardware/software dei computer in rete.

## 🚀 Novità v1.0 - Dashboard Web!

- ✅ **Dashboard web moderna** con grafici interattivi
- ✅ **Database SQLite** per archiviazione strutturata
- ✅ **API REST** complete per integrazione
- ✅ **Auto-refresh** real-time ogni 30 secondi
- ✅ **Alert intelligenti** per spazio disco critico

🌐 **Accedi alla dashboard**: http://localhost:3000 (dopo aver avviato il server)

## 📁 Componenti del Sistema

### Script PowerShell
- **`system_info.ps1`** - Script base raccolta informazioni sistema
- **`collect_client_info_silent.ps1`** - ✨ **VERSIONE SILENZIOSA** per deployment
- **`collect_sqlite_clean.ps1`** - 🆕 **Raccolta con database SQLite**
- **`SQLiteManager_Simple.psm1`** - 🆕 **Modulo gestione database**

### Dashboard Web 🆕
- **`web-dashboard/server.js`** - Backend Node.js + Express + API REST
- **`web-dashboard/public/index.html`** - Frontend moderno con Bootstrap 5.3
- **`web-dashboard/public/dashboard.js`** - JavaScript client con Chart.js
- **`web-dashboard/package.json`** - Dipendenze Node.js
- **`deploy_silent.ps1`** - ✨ **DEPLOYMENT SILENZIOSO** - Distribuzione nascosta sui client
- **`analyze_data.ps1`** - Script per analizzare e generare report dai dati raccolti
- **`system_info.ps1`** - Script originale semplificato (per test locali)

### Script per Esecuzione Invisibile
- **`run_silent.bat`** - File batch per esecuzione nascosta via PowerShell
- **`run_invisible.vbs`** - ✨ **COMPLETAMENTE INVISIBILE** - Script VBScript senza finestre

## � Modalità Silenziosa - ZERO Impatto Utente

## 🛠️ Setup Rapido Dashboard Web

### 1. Raccogli dati iniziali
```powershell
# Esegui raccolta con database SQLite
powershell -ExecutionPolicy Bypass -File collect_sqlite_clean.ps1
```

### 2. Avvia la dashboard
```powershell
cd web-dashboard
npm install          # Solo la prima volta
npm start            # Avvia il server
```

### 3. Apri la dashboard
🌐 **URL**: http://localhost:3000

### 4. Funzionalità disponibili
- **Overview**: Statistiche generali, grafici OS/produttori, timeline
- **Computer**: Lista computer con stato dischi e dettagli hardware
- **Dischi**: Tabella utilizzo spazio con alert visivi
- **Alert**: Notifiche critiche per dischi > 80%

---

## ❓ **Domande Frequenti**

### ❓ **Risposta alla domanda: "Gli utenti vedranno finestre?"**

**NO! Con la modalità silenziosa gli utenti NON vedranno NESSUNA finestra.**

### 🎯 Livelli di Visibilità:

#### 1. **Script Standard** (`collect_client_info.ps1`)
- ❌ **Visibile**: Mostra finestra PowerShell durante l'esecuzione
- ✅ **Per**: Test e debugging
- ❌ **Per**: Ambiente di produzione

#### 2. **Script Silenzioso** (`collect_client_info_silent.ps1`)
- ✅ **Nascosto**: Nessuna finestra visibile
- ✅ **Logging**: Solo file di log in %TEMP%
- ✅ **Per**: Produzione con controllo

#### 3. **Esecuzione VBScript** (`run_invisible.vbs`)
- ✅ **Completamente Invisibile**: Zero presenza visiva
- ✅ **Per**: Massima trasparenza all'utente
- ✅ **Ideale**: Distribuzione via GPO

### 🛠️ Implementazione Modalità Silenziosa:

```powershell
# Metodo 1: PowerShell nascosto
.\collect_client_info_silent.ps1 -DatabasePath "\\server\data"

# Metodo 2: VBScript invisibile (RACCOMANDATO)
cscript //nologo run_invisible.vbs

# Metodo 3: Task Scheduler automatico
.\deploy_silent.ps1 -UseTaskScheduler -TaskTime "02:00"
```

### 📋 Caratteristiche Modalità Silenziosa:

- ✅ **Zero finestre popup**
- ✅ **Zero interruzioni all'utente**
- ✅ **Esecuzione in background**
- ✅ **Logging dettagliato nascosto**
- ✅ **Gestione errori silenziosa**
- ✅ **Exit codes per monitoraggio automatico**
- ✅ **Compatibile con GPO e SCCM**

### 🎛️ Controllo e Monitoraggio:

```powershell
# Verifica esecuzione (admin only)
Get-Content "$env:TEMP\MonitorIT_Collection.log"

# Controllo task schedulati
Get-ScheduledTask -TaskName "MonitorIT_Collection"

# Verifica ultima raccolta
Get-ChildItem "\\server\data\client_inventory.csv" | Select-Object LastWriteTime
```

## �🚀 Come Utilizzare il Sistema

### 1. Preparazione Ambiente

#### Requisiti:
- Windows PowerShell 5.1 o superiore
- Diritti amministrativi sui client target
- Cartella condivisa di rete per il database centrale
- WinRM abilitato per esecuzione remota (opzionale)

#### Setup Cartella Condivisa:
```powershell
# Esempio: crea cartella condivisa su server
New-Item -ItemType Directory -Path "C:\ClientData" -Force
New-SmbShare -Name "ClientData" -Path "C:\ClientData" -FullAccess "Domain\AdminGroup"
```

### 2. Raccolta Dati da Singolo Client

#### Esecuzione Visibile (per test):
```powershell
# Raccolta base con salvataggio locale
.\collect_client_info.ps1

# Raccolta con invio a cartella di rete
.\collect_client_info.ps1 -DatabasePath "\\server\ClientData" -OutputFormat "CSV"
```

#### ✨ Esecuzione SILENZIOSA (per produzione):
```powershell
# Modalità silenziosa - NESSUNA finestra visibile
.\collect_client_info_silent.ps1 -DatabasePath "\\server\ClientData" -OutputFormat "CSV"

# Esecuzione completamente invisibile via VBScript
cscript //nologo run_invisible.vbs

# Esecuzione nascosta via batch
run_silent.bat
```

#### Parametri Disponibili:
- **`-DatabasePath`** - Percorso cartella condivisa di rete
- **`-OutputFormat`** - Formato output: CSV, JSON, o TXT
- **`-SendToDatabase`** - Flag per abilitare invio a database
- **`-ServerEndpoint`** - URL endpoint API REST

### 3. Distribuzione su Più Client

#### Distribuzione Standard (con finestre):
```powershell
# Specifica computer manualmente
.\deploy_collection.ps1 -ComputerNames @("PC001", "PC002", "PC003") -NetworkShare "\\server\ClientData"
```

#### ✨ Distribuzione SILENZIOSA (raccomandato per produzione):
```powershell
# Distribuzione completamente nascosta agli utenti
.\deploy_silent.ps1 -ComputerNames @("PC001", "PC002", "PC003") -NetworkShare "\\server\ClientData"

# Creazione task schedulato silenzioso (esecuzione automatica settimanale)
.\deploy_silent.ps1 -ComputerNames @("PC001", "PC002") -NetworkShare "\\server\ClientData" -UseTaskScheduler -TaskTime "02:00"

# Distribuzione con credenziali e test connettività
$cred = Get-Credential
.\deploy_silent.ps1 -ComputerNames @("PC001", "PC002") -NetworkShare "\\server\ClientData" -Credential $cred -HideWindows
```

#### Funzionalità Deploy:
- ✅ Test connettività automatico
- ✅ Copia script sui client remoti
- ✅ Esecuzione remota via WinRM
- ✅ Gestione errori e retry
- ✅ Report di deployment

### 4. Analisi e Report

#### Generazione Report:
```powershell
# Report testuale base
.\analyze_data.ps1 -DataPath "\\server\ClientData\client_inventory.csv"

# Report completo con HTML
.\analyze_data.ps1 -DataPath "\\server\ClientData\client_inventory.csv" -GenerateHTML -ReportPath ".\reports"

# Export per Excel
.\analyze_data.ps1 -GenerateHTML -ExportToExcel
```

#### Report Inclusi:
- 📊 Statistiche generali (totale PC, RAM, etc.)
- 🖥️ Distribuzione sistemi operativi
- 🏭 Distribuzione produttori hardware
- 💾 Analisi utilizzo dischi
- ⚠️ Alert per dischi oltre 80% di utilizzo
- 📋 Dettaglio completo tutti i client

## 📊 Dati Raccolti

### Informazioni Sistema:
- Nome computer e dominio
- Utente corrente
- Indirizzo IP e MAC address
- Sistema operativo (nome, versione, architettura)
- Produttore e modello hardware
- Numero seriale BIOS
- RAM totale

### Informazioni Dischi:
- Lettera drive e etichetta volume
- Dimensione totale e spazio libero
- Percentuale utilizzo
- File system
- Supporto per dischi multipli

### Metadati:
- Data e ora raccolta
- Identificativo univoco client
- Formato esportazione

## 🔧 Configurazioni Avanzate

### Automatizzazione con Task Scheduler:
```powershell
# Crea task per raccolta automatica settimanale
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-File C:\Scripts\collect_client_info.ps1 -DatabasePath \\server\ClientData"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At 8AM
Register-ScheduledTask -TaskName "ClientInventory" -Action $action -Trigger $trigger
```

### Integrazione con Active Directory:
```powershell
# Ottieni lista computer da AD
$computers = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name
.\deploy_collection.ps1 -ComputerNames $computers -NetworkShare "\\server\ClientData"
```

### Database SQL Server:
Per integrare con SQL Server, modifica lo script per utilizzare invoke-sqlcmd:
```powershell
# Esempio di integrazione SQL
$connectionString = "Server=SQLSERVER;Database=Inventory;Integrated Security=true"
Invoke-Sqlcmd -ConnectionString $connectionString -Query "INSERT INTO Computers VALUES (...)"
```

## 🛡️ Sicurezza e Best Practices

### Permessi Minimi:
- Lettura: Cartella condivisa di rete
- Scrittura: Cartella condivisa di rete
- WinRM: Solo se esecuzione remota
- Amministratore locale: Per informazioni hardware complete

### Gestione Errori:
- ✅ Backup locale sempre creato
- ✅ Fallback su connessione di rete
- ✅ Log dettagliati per troubleshooting
- ✅ Retry automatico per operazioni critiche

### Pulizia Dati:
```powershell
# Script per pulizia dati vecchi (esegui periodicamente)
Get-ChildItem "\\server\ClientData" -Filter "*.csv" | 
    Where-Object {$_.LastWriteTime -lt (Get-Date).AddDays(-30)} | 
    Remove-Item
```

## 📋 Esempi di Uso Comune

### Scenario 1: Inventario Mensile
```powershell
# 1. Raccogli da tutti i PC del dominio
$computers = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name
.\deploy_collection.ps1 -ComputerNames $computers -NetworkShare "\\server\ClientData"

# 2. Genera report completo
.\analyze_data.ps1 -GenerateHTML -ExportToExcel -ReportPath ".\reports\$(Get-Date -Format 'yyyy-MM')"
```

### Scenario 2: Monitoraggio Spazio Disco
```powershell
# 1. Raccolta mirata
.\collect_client_info.ps1 -DatabasePath "\\server\ClientData"

# 2. Analisi immediata con focus sui dischi
.\analyze_data.ps1 -DataPath "\\server\ClientData\client_inventory.csv"
```

### Scenario 3: Audit di Conformità
```powershell
# 1. Raccolta completa con timestamp
.\deploy_collection.ps1 -NetworkShare "\\server\ClientData\Audit_$(Get-Date -Format 'yyyyMMdd')"

# 2. Report dettagliato per audit
.\analyze_data.ps1 -GenerateHTML -ExportToExcel
```

## 🔍 Troubleshooting

### Problemi Comuni:

**Errore "Access Denied"**
- Verifica permessi cartella condivisa
- Controlla credenziali utente
- Testa accesso manuale alla cartella

**Errore WinRM**
- Abilita WinRM: `Enable-PSRemoting -Force`
- Configura TrustedHosts se necessario
- Verifica firewall Windows

**Dati Incompleti**
- Esegui come amministratore
- Verifica driver WMI/CIM
- Controlla log eventi Windows

**Performance Lente**
- Riduci numero client simultanei
- Aumenta timeout di rete
- Usa filtri per dati specifici

## 📈 Estensioni Future

- 🔌 Integrazione con SCCM/Intune
- 📡 Monitoraggio real-time
- 🎯 Alert automatici
- 📱 Dashboard web
- 🔄 Sincronizzazione bidirezionale
- 📊 Analytics avanzati

---

**Sviluppato per MonitorIT - Sistema di Inventario Client**
*Versione 2.0 - Network Ready*