// Server Node.js per Dashboard MonitorIT
// Versione: 1.0 - JavaScript SQLite Dashboard
// Creato il: 23 settembre 2025

const express = require('express');
const sqlite3 = require('sqlite3').verbose();
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');
const path = require('path');
const fs = require('fs');

const app = express();
const PORT = process.env.PORT || 3000;

// Configurazione middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'", "https://cdnjs.cloudflare.com"],
            scriptSrc: ["'self'", "https://cdnjs.cloudflare.com", "https://cdn.jsdelivr.net"],
            imgSrc: ["'self'", "data:", "https:"],
        },
    },
}));
app.use(compression());
app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Configurazione database SQLite
const DB_PATH = path.join(__dirname, '..', 'test_data', 'inventory.db');

// Funzione per connessione database
function getDbConnection() {
    return new sqlite3.Database(DB_PATH, sqlite3.OPEN_READONLY, (err) => {
        if (err) {
            console.error('Errore connessione database:', err.message);
        }
    });
}

// Middleware per verificare esistenza database
function checkDatabase(req, res, next) {
    if (!fs.existsSync(DB_PATH)) {
        return res.status(404).json({
            error: 'Database non trovato',
            message: 'Il database SQLite non esiste. Esegui prima la raccolta dati.',
            path: DB_PATH
        });
    }
    next();
}

// === API ENDPOINTS ===

// GET /api/status - Stato del sistema
app.get('/api/status', checkDatabase, (req, res) => {
    const db = getDbConnection();
    
    const queries = {
        computers: "SELECT COUNT(DISTINCT computer_name) as count FROM computers",
        totalRecords: "SELECT COUNT(*) as count FROM computers",
        disks: "SELECT COUNT(*) as count FROM disks",
        lastUpdate: "SELECT MAX(collection_date) as last_update FROM computers"
    };
    
    const results = {};
    let completed = 0;
    const totalQueries = Object.keys(queries).length;
    
    Object.entries(queries).forEach(([key, query]) => {
        db.get(query, (err, row) => {
            if (err) {
                results[key] = { error: err.message };
            } else {
                results[key] = row;
            }
            
            completed++;
            if (completed === totalQueries) {
                db.close();
                res.json({
                    status: 'ok',
                    timestamp: new Date().toISOString(),
                    database_path: DB_PATH,
                    stats: results
                });
            }
        });
    });
});

// GET /api/computers - Lista computer
app.get('/api/computers', checkDatabase, (req, res) => {
    const db = getDbConnection();
    
    const query = `
        SELECT 
            c.*,
            (SELECT COUNT(*) FROM disks WHERE computer_id = c.id) as disk_count,
            (SELECT AVG(percent_used) FROM disks WHERE computer_id = c.id) as avg_disk_usage
        FROM computers c 
        ORDER BY c.collection_date DESC
    `;
    
    db.all(query, (err, rows) => {
        db.close();
        if (err) {
            res.status(500).json({ error: err.message });
        } else {
            res.json({
                success: true,
                count: rows.length,
                data: rows
            });
        }
    });
});

// GET /api/computers/:name - Dettaglio singolo computer
app.get('/api/computers/:name', checkDatabase, (req, res) => {
    const db = getDbConnection();
    const computerName = req.params.name;
    
    const computerQuery = `
        SELECT * FROM computers 
        WHERE computer_name = ? 
        ORDER BY collection_date DESC 
        LIMIT 1
    `;
    
    const disksQuery = `
        SELECT d.* FROM disks d
        JOIN computers c ON d.computer_id = c.id
        WHERE c.computer_name = ?
        ORDER BY d.drive_letter
    `;
    
    db.get(computerQuery, [computerName], (err, computer) => {
        if (err) {
            db.close();
            return res.status(500).json({ error: err.message });
        }
        
        if (!computer) {
            db.close();
            return res.status(404).json({ error: 'Computer non trovato' });
        }
        
        db.all(disksQuery, [computerName], (err, disks) => {
            db.close();
            if (err) {
                return res.status(500).json({ error: err.message });
            }
            
            res.json({
                success: true,
                computer: computer,
                disks: disks
            });
        });
    });
});

// GET /api/disks - Analisi dischi
app.get('/api/disks', checkDatabase, (req, res) => {
    const db = getDbConnection();
    
    const query = `
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
    `;
    
    db.all(query, (err, rows) => {
        db.close();
        if (err) {
            res.status(500).json({ error: err.message });
        } else {
            res.json({
                success: true,
                count: rows.length,
                data: rows
            });
        }
    });
});

// GET /api/alerts - Alert critici
app.get('/api/alerts', checkDatabase, (req, res) => {
    const db = getDbConnection();
    
    const criticalDisksQuery = `
        SELECT 
            c.computer_name,
            c.user_name,
            c.ip_address,
            d.drive_letter,
            d.volume_label,
            d.percent_used,
            d.free_space_gb,
            d.total_size_gb,
            'disk_space' as alert_type,
            'Spazio disco critico' as alert_message
        FROM disks d
        JOIN computers c ON d.computer_id = c.id
        WHERE d.percent_used > 80
        ORDER BY d.percent_used DESC
    `;
    
    const lowRamQuery = `
        SELECT 
            computer_name,
            user_name,
            ip_address,
            total_ram_gb,
            '' as drive_letter,
            '' as volume_label,
            0 as percent_used,
            0 as free_space_gb,
            0 as total_size_gb,
            'low_ram' as alert_type,
            'RAM insufficiente' as alert_message
        FROM computers 
        WHERE total_ram_gb < 4
        ORDER BY total_ram_gb ASC
    `;
    
    db.all(criticalDisksQuery, (err, diskAlerts) => {
        if (err) {
            db.close();
            return res.status(500).json({ error: err.message });
        }
        
        db.all(lowRamQuery, (err, ramAlerts) => {
            db.close();
            if (err) {
                return res.status(500).json({ error: err.message });
            }
            
            const allAlerts = [...diskAlerts, ...ramAlerts];
            
            res.json({
                success: true,
                count: allAlerts.length,
                critical_disks: diskAlerts.length,
                low_ram_computers: ramAlerts.length,
                data: allAlerts
            });
        });
    });
});

// GET /api/statistics - Statistiche aggregate
app.get('/api/statistics', checkDatabase, (req, res) => {
    const db = getDbConnection();
    
    const osStatsQuery = `
        SELECT os_name, COUNT(DISTINCT computer_name) as count 
        FROM computers 
        GROUP BY os_name 
        ORDER BY count DESC
    `;
    
    const manufacturerStatsQuery = `
        SELECT manufacturer, COUNT(DISTINCT computer_name) as count 
        FROM computers 
        GROUP BY manufacturer 
        ORDER BY count DESC
    `;
    
    const diskStatsQuery = `
        SELECT 
            AVG(percent_used) as avg_usage,
            MAX(percent_used) as max_usage,
            SUM(total_size_gb) as total_space,
            SUM(free_space_gb) as total_free
        FROM disks
    `;
    
    const results = {};
    let completed = 0;
    
    db.all(osStatsQuery, (err, osStats) => {
        results.os_distribution = err ? [] : osStats;
        completed++;
        if (completed === 3) sendResults();
    });
    
    db.all(manufacturerStatsQuery, (err, manufStats) => {
        results.manufacturer_distribution = err ? [] : manufStats;
        completed++;
        if (completed === 3) sendResults();
    });
    
    db.get(diskStatsQuery, (err, diskStats) => {
        results.disk_statistics = err ? {} : diskStats;
        completed++;
        if (completed === 3) sendResults();
    });
    
    function sendResults() {
        db.close();
        res.json({
            success: true,
            data: results
        });
    }
});

// GET /api/timeline - Timeline raccolta dati
app.get('/api/timeline', checkDatabase, (req, res) => {
    const db = getDbConnection();
    
    const query = `
        SELECT 
            DATE(collection_date) as date,
            COUNT(DISTINCT computer_name) as unique_computers,
            COUNT(*) as total_collections
        FROM computers
        WHERE collection_date >= date('now', '-30 days')
        GROUP BY DATE(collection_date)
        ORDER BY date DESC
    `;
    
    db.all(query, (err, rows) => {
        db.close();
        if (err) {
            res.status(500).json({ error: err.message });
        } else {
            res.json({
                success: true,
                count: rows.length,
                data: rows
            });
        }
    });
});

// Serve la dashboard HTML
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// Gestione errori 404
app.use((req, res) => {
    res.status(404).json({
        error: 'Endpoint non trovato',
        available_endpoints: [
            'GET /api/status',
            'GET /api/computers',
            'GET /api/computers/:name',
            'GET /api/disks',
            'GET /api/alerts',
            'GET /api/statistics',
            'GET /api/timeline'
        ]
    });
});

// Gestione errori generali
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(500).json({
        error: 'Errore interno del server',
        message: err.message
    });
});

// Avvio server
app.listen(PORT, () => {
    console.log(`🚀 MonitorIT Dashboard Server avviato su http://localhost:${PORT}`);
    console.log(`📊 Database SQLite: ${DB_PATH}`);
    console.log(`🔗 API disponibili su http://localhost:${PORT}/api/`);
    
    // Verifica esistenza database
    if (fs.existsSync(DB_PATH)) {
        console.log('✅ Database SQLite trovato e pronto');
    } else {
        console.log('⚠️  Database SQLite non trovato. Esegui prima la raccolta dati.');
    }
});

module.exports = app;