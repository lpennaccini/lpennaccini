# MonitorIT Dashboard Web 🖥️

Una dashboard web moderna e responsiva per visualizzare i dati raccolti dal sistema MonitorIT.

## 🚀 Caratteristiche

- **Dashboard moderna**: Interfaccia pulita e responsiva basata su Bootstrap 5.3
- **Grafici interattivi**: Visualizzazioni con Chart.js per statistiche OS, produttori, timeline
- **Monitoraggio real-time**: Auto-refresh ogni 30 secondi
- **Alert intelligenti**: Notifiche per dischi pieni e problemi di sistema
- **API REST**: Backend Node.js con Express per accesso ai dati SQLite

## 📦 Installazione e Avvio

### 1. Prerequisiti
- Node.js 14+ installato
- Database SQLite con dati raccolti da MonitorIT

### 2. Installazione dipendenze
```powershell
cd web-dashboard
npm install
```

### 3. Avvio del server
```powershell
npm start
```

Il server sarà disponibile su: **http://localhost:3000**

## 🔧 Configurazione

### Database SQLite
Il server cerca il database SQLite in:
```
../test_data/inventory.db
```

Se il database non esiste, esegui prima la raccolta dati:
```powershell
powershell -ExecutionPolicy Bypass -File collect_sqlite_clean.ps1
```

### Porta del server
Per cambiare la porta (default 3000), modifica `server.js`:
```javascript
const PORT = process.env.PORT || 3000;
```

## 📊 Funzionalità Dashboard

### Tab Overview
- **Statistiche generali**: Totale computer, dischi, alert critici
- **Grafici OS Distribution**: Distribuzione sistemi operativi
- **Grafici Produttori**: Computer per produttore
- **Timeline**: Andamento raccolte nel tempo

### Tab Computer
- **Lista computer**: Card visuali con informazioni complete
- **Stato dischi**: Indicatori colorati per utilizzo
- **Dettagli hardware**: RAM, IP, utente, sistema operativo

### Tab Dischi
- **Tabella dettagliata**: Tutti i dischi con utilizzo
- **Alert visivi**: Righe colorate per dischi critici
- **Statistiche spazio**: Utilizzato, libero, percentuale

### Tab Alert
- **Alert critici**: Dischi > 80% utilizzo
- **Notifiche sistema**: Problemi di memoria o spazio
- **Informazioni complete**: Computer, utente, dettagli tecnici

## 🛠️ API Endpoints

### Stato generale
```
GET /api/status
```
Restituisce statistiche generali e stato database.

### Statistiche
```
GET /api/statistics
```
Distribuzioni OS, produttori, statistiche dischi.

### Timeline
```
GET /api/timeline
```
Andamento raccolte dati negli ultimi 30 giorni.

### Computer
```
GET /api/computers
```
Lista completa computer con dettagli hardware.

### Dischi
```
GET /api/disks
```
Tutti i dischi con informazioni utilizzo.

### Alert
```
GET /api/alerts
```
Alert critici per spazio disco e sistema.

## 🎨 Personalizzazione

### Temi e colori
Modifica il CSS in `public/index.html` per personalizzare:
- Colori brand
- Layout dashboard
- Stili grafici

### Soglie alert
Modifica le soglie in `dashboard.js`:
```javascript
const statusClass = diskUsage > 80 ? 'critical' : diskUsage > 60 ? 'warning' : '';
```

### Frequenza aggiornamento
Cambia l'intervallo di refresh in `dashboard.js`:
```javascript
// Default: 30 secondi
this.refreshInterval = setInterval(() => {
    this.loadStatus();
}, 30000);
```

## 🔒 Sicurezza

- **Helmet.js**: Headers di sicurezza HTTP
- **CORS**: Cross-Origin Resource Sharing configurato
- **Rate Limiting**: Protezione da attacchi DDoS
- **Validazione input**: Sanitizzazione parametri API

## 📱 Compatibilità

- **Browser moderni**: Chrome, Firefox, Edge, Safari
- **Responsive design**: Desktop, tablet, mobile
- **PWA ready**: Installabile come app

## 🐛 Debugging

### Logs del server
I logs sono visibili nella console del server:
```
🚀 MonitorIT Dashboard Server avviato su http://localhost:3000
📊 Database SQLite: C:\path\to\inventory.db
🔗 API disponibili su http://localhost:3000/api/
```

### Browser Developer Tools
Apri F12 per vedere:
- Console JavaScript per errori client
- Network tab per chiamate API
- Storage per dati cached

### Test API
Testa gli endpoint direttamente:
```
http://localhost:3000/api/status
http://localhost:3000/api/computers
http://localhost:3000/api/disks
http://localhost:3000/api/alerts
```

## 📈 Performance

- **Caching intelligente**: Dati cached lato client
- **Lazy loading**: Tab caricati on-demand
- **Grafici ottimizzati**: Chart.js con performance tuning
- **API efficiente**: Query SQLite ottimizzate

## 🔄 Aggiornamenti

Per aggiornare la dashboard:
1. Ferma il server (Ctrl+C)
2. Aggiorna i file
3. Riavvia con `npm start`

## 📞 Supporto

Per problemi o miglioramenti:
- Controlla i logs del server
- Verifica la connessione database
- Testa le API direttamente
- Controlla la console browser

---

**MonitorIT Dashboard v1.0** - Sistema di monitoraggio Windows moderno e efficace! 🎯