// Dashboard JavaScript per MonitorIT
// Versione: 1.0 - Modern JavaScript Dashboard
// Creato il: 23 settembre 2025

class MonitorITDashboard {
    constructor() {
        this.apiBase = '/api';
        this.charts = {};
        this.refreshInterval = null;
        this.init();
    }

    async init() {
        console.log('🚀 Inizializzazione MonitorIT Dashboard...');
        
        // Carica i dati iniziali
        await this.loadInitialData();
        
        // Imposta auto-refresh ogni 30 secondi
        this.startAutoRefresh();
        
        // Event listeners per i tab
        this.setupTabListeners();
        
        console.log('✅ Dashboard inizializzata con successo!');
    }

    async loadInitialData() {
        try {
            showLoading(true);
            
            // Carica stato generale
            await this.loadStatus();
            
            // Carica statistiche per i grafici
            await this.loadStatistics();
            
            // Carica timeline
            await this.loadTimeline();
            
            showLoading(false);
        } catch (error) {
            console.error('❌ Errore caricamento dati iniziali:', error);
            this.showError('Errore nel caricamento dei dati. Verifica che il server sia attivo.');
            showLoading(false);
        }
    }

    async loadStatus() {
        try {
            const response = await fetch(`${this.apiBase}/status`);
            const data = await response.json();
            
            if (data.status === 'ok') {
                // Aggiorna le statistiche principali
                document.getElementById('totalComputers').textContent = data.stats.computers.count || 0;
                document.getElementById('totalDisks').textContent = data.stats.disks.count || 0;
                
                // Aggiorna timestamp
                const lastUpdate = new Date(data.stats.lastUpdate.last_update).toLocaleString('it-IT');
                document.getElementById('lastUpdate').textContent = `Ultimo aggiornamento: ${lastUpdate}`;
                
                // Carica alert critici
                await this.loadAlertCount();
                
                // Carica statistiche dischi
                await this.loadDiskStatistics();
            }
        } catch (error) {
            console.error('❌ Errore caricamento status:', error);
        }
    }

    async loadAlertCount() {
        try {
            const response = await fetch(`${this.apiBase}/alerts`);
            const data = await response.json();
            
            if (data.success) {
                document.getElementById('criticalAlerts').textContent = data.count || 0;
            }
        } catch (error) {
            console.error('❌ Errore caricamento alert count:', error);
        }
    }

    async loadDiskStatistics() {
        try {
            const response = await fetch(`${this.apiBase}/statistics`);
            const data = await response.json();
            
            if (data.success && data.data.disk_statistics) {
                const avgUsage = Math.round(data.data.disk_statistics.avg_usage || 0);
                document.getElementById('averageDiskUsage').textContent = `${avgUsage}%`;
            }
        } catch (error) {
            console.error('❌ Errore caricamento disk statistics:', error);
        }
    }

    async loadStatistics() {
        try {
            const response = await fetch(`${this.apiBase}/statistics`);
            const data = await response.json();
            
            if (data.success) {
                this.createOSChart(data.data.os_distribution);
                this.createManufacturerChart(data.data.manufacturer_distribution);
            }
        } catch (error) {
            console.error('❌ Errore caricamento statistiche:', error);
        }
    }

    async loadTimeline() {
        try {
            const response = await fetch(`${this.apiBase}/timeline`);
            const data = await response.json();
            
            if (data.success) {
                this.createTimelineChart(data.data);
            }
        } catch (error) {
            console.error('❌ Errore caricamento timeline:', error);
        }
    }

    async loadComputers() {
        try {
            const response = await fetch(`${this.apiBase}/computers`);
            const data = await response.json();
            
            if (data.success) {
                this.renderComputers(data.data);
            }
        } catch (error) {
            console.error('❌ Errore caricamento computer:', error);
            this.showError('Errore nel caricamento dei computer', 'computersContainer');
        }
    }

    async loadDisks() {
        try {
            const response = await fetch(`${this.apiBase}/disks`);
            const data = await response.json();
            
            if (data.success) {
                this.renderDisks(data.data);
            }
        } catch (error) {
            console.error('❌ Errore caricamento dischi:', error);
            this.showError('Errore nel caricamento dei dischi', 'disksContainer');
        }
    }

    async loadAlerts() {
        try {
            const response = await fetch(`${this.apiBase}/alerts`);
            const data = await response.json();
            
            if (data.success) {
                this.renderAlerts(data.data);
            }
        } catch (error) {
            console.error('❌ Errore caricamento alert:', error);
            this.showError('Errore nel caricamento degli alert', 'alertsContainer');
        }
    }

    createOSChart(osData) {
        const ctx = document.getElementById('osChart').getContext('2d');
        
        if (this.charts.osChart) {
            this.charts.osChart.destroy();
        }
        
        this.charts.osChart = new Chart(ctx, {
            type: 'doughnut',
            data: {
                labels: osData.map(item => item.os_name),
                datasets: [{
                    data: osData.map(item => item.count),
                    backgroundColor: [
                        '#3498db', '#e74c3c', '#2ecc71', '#f39c12', 
                        '#9b59b6', '#1abc9c', '#34495e', '#e67e22'
                    ],
                    borderWidth: 2,
                    borderColor: '#fff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'bottom'
                    }
                }
            }
        });
    }

    createManufacturerChart(manufData) {
        const ctx = document.getElementById('manufacturerChart').getContext('2d');
        
        if (this.charts.manufacturerChart) {
            this.charts.manufacturerChart.destroy();
        }
        
        this.charts.manufacturerChart = new Chart(ctx, {
            type: 'bar',
            data: {
                labels: manufData.map(item => item.manufacturer),
                datasets: [{
                    label: 'Computer',
                    data: manufData.map(item => item.count),
                    backgroundColor: '#3498db',
                    borderColor: '#2980b9',
                    borderWidth: 1
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        display: false
                    }
                },
                scales: {
                    y: {
                        beginAtZero: true,
                        ticks: {
                            stepSize: 1
                        }
                    }
                }
            }
        });
    }

    createTimelineChart(timelineData) {
        const ctx = document.getElementById('timelineChart').getContext('2d');
        
        if (this.charts.timelineChart) {
            this.charts.timelineChart.destroy();
        }
        
        // Inverti l'ordine per mostrare dal più vecchio al più recente
        const sortedData = timelineData.reverse();
        
        this.charts.timelineChart = new Chart(ctx, {
            type: 'line',
            data: {
                labels: sortedData.map(item => new Date(item.date).toLocaleDateString('it-IT')),
                datasets: [{
                    label: 'Computer Unici',
                    data: sortedData.map(item => item.unique_computers),
                    borderColor: '#3498db',
                    backgroundColor: 'rgba(52, 152, 219, 0.1)',
                    borderWidth: 2,
                    fill: true
                }, {
                    label: 'Raccolte Totali',
                    data: sortedData.map(item => item.total_collections),
                    borderColor: '#e74c3c',
                    backgroundColor: 'rgba(231, 76, 60, 0.1)',
                    borderWidth: 2,
                    fill: true
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
    }

    renderComputers(computers) {
        const container = document.getElementById('computersContainer');
        
        if (computers.length === 0) {
            container.innerHTML = `
                <div class="text-center p-4">
                    <i class="fas fa-desktop fa-3x text-muted mb-3"></i>
                    <h5>Nessun computer trovato</h5>
                    <p class="text-muted">Esegui la raccolta dati per visualizzare i computer.</p>
                </div>
            `;
            return;
        }
        
        let html = '<div class="row">';
        
        computers.forEach(computer => {
            const diskUsage = Math.round(computer.avg_disk_usage || 0);
            const statusClass = diskUsage > 80 ? 'critical' : diskUsage > 60 ? 'warning' : '';
            const statusIcon = diskUsage > 80 ? 'status-critical' : diskUsage > 60 ? 'status-warning' : 'status-online';
            
            html += `
                <div class="col-md-6 col-lg-4 mb-3">
                    <div class="card computer-card ${statusClass}">
                        <div class="card-body">
                            <h6 class="card-title">
                                <span class="status-indicator ${statusIcon}"></span>
                                ${computer.computer_name}
                            </h6>
                            <p class="card-text">
                                <small class="text-muted">
                                    <i class="fas fa-user me-1"></i>${computer.user_name}<br>
                                    <i class="fas fa-network-wired me-1"></i>${computer.ip_address}<br>
                                    <i class="fas fa-windows me-1"></i>${computer.os_name}<br>
                                    <i class="fas fa-memory me-1"></i>${computer.total_ram_gb} GB RAM<br>
                                    <i class="fas fa-hdd me-1"></i>${computer.disk_count} dischi
                                </small>
                            </p>
                            <div class="mb-2">
                                <small>Utilizzo dischi medio: ${diskUsage}%</small>
                                <div class="progress progress-custom">
                                    <div class="progress-bar ${diskUsage > 80 ? 'bg-danger' : diskUsage > 60 ? 'bg-warning' : 'bg-success'}" 
                                         style="width: ${diskUsage}%"></div>
                                </div>
                            </div>
                            <small class="text-muted">
                                <i class="fas fa-clock me-1"></i>
                                ${new Date(computer.collection_date).toLocaleString('it-IT')}
                            </small>
                        </div>
                    </div>
                </div>
            `;
        });
        
        html += '</div>';
        container.innerHTML = html;
    }

    renderDisks(disks) {
        const container = document.getElementById('disksContainer');
        
        if (disks.length === 0) {
            container.innerHTML = `
                <div class="text-center p-4">
                    <i class="fas fa-hdd fa-3x text-muted mb-3"></i>
                    <h5>Nessun disco trovato</h5>
                </div>
            `;
            return;
        }
        
        let html = `
            <div class="table-responsive">
                <table class="table table-hover">
                    <thead class="table-dark">
                        <tr>
                            <th>Computer</th>
                            <th>Drive</th>
                            <th>Etichetta</th>
                            <th>Dimensione</th>
                            <th>Utilizzato</th>
                            <th>Libero</th>
                            <th>Utilizzo %</th>
                            <th>File System</th>
                        </tr>
                    </thead>
                    <tbody>
        `;
        
        disks.forEach(disk => {
            const usagePercent = Math.round(disk.percent_used);
            const statusClass = usagePercent > 80 ? 'table-danger' : usagePercent > 60 ? 'table-warning' : '';
            
            html += `
                <tr class="${statusClass}">
                    <td><strong>${disk.computer_name}</strong></td>
                    <td><span class="badge bg-primary">${disk.drive_letter}</span></td>
                    <td>${disk.volume_label || 'N/A'}</td>
                    <td>${Math.round(disk.total_size_gb)} GB</td>
                    <td>${Math.round(disk.used_space_gb)} GB</td>
                    <td>${Math.round(disk.free_space_gb)} GB</td>
                    <td>
                        <div class="d-flex align-items-center">
                            <span class="me-2">${usagePercent}%</span>
                            <div class="progress progress-custom flex-grow-1">
                                <div class="progress-bar ${usagePercent > 80 ? 'bg-danger' : usagePercent > 60 ? 'bg-warning' : 'bg-success'}" 
                                     style="width: ${usagePercent}%"></div>
                            </div>
                        </div>
                    </td>
                    <td>${disk.file_system}</td>
                </tr>
            `;
        });
        
        html += '</tbody></table></div>';
        container.innerHTML = html;
    }

    renderAlerts(alerts) {
        const container = document.getElementById('alertsContainer');
        
        if (alerts.length === 0) {
            container.innerHTML = `
                <div class="alert alert-success" role="alert">
                    <i class="fas fa-check-circle me-2"></i>
                    <strong>Ottimo!</strong> Nessun alert critico al momento.
                </div>
            `;
            return;
        }
        
        let html = '';
        
        alerts.forEach(alert => {
            const alertClass = alert.alert_type === 'disk_space' ? 'alert-danger' : 'alert-warning';
            const icon = alert.alert_type === 'disk_space' ? 'fas fa-hdd' : 'fas fa-memory';
            
            html += `
                <div class="alert ${alertClass}" role="alert">
                    <h6 class="alert-heading">
                        <i class="${icon} me-2"></i>
                        ${alert.alert_message}
                    </h6>
                    <p class="mb-1">
                        <strong>Computer:</strong> ${alert.computer_name} 
                        <span class="text-muted">(${alert.user_name})</span>
                    </p>
                    <p class="mb-1">
                        <strong>IP:</strong> ${alert.ip_address}
                    </p>
                    ${alert.alert_type === 'disk_space' ? `
                        <p class="mb-1">
                            <strong>Disco:</strong> ${alert.drive_letter} (${alert.volume_label})
                        </p>
                        <p class="mb-0">
                            <strong>Utilizzo:</strong> ${Math.round(alert.percent_used)}% 
                            - <strong>Spazio libero:</strong> ${Math.round(alert.free_space_gb)} GB
                        </p>
                    ` : `
                        <p class="mb-0">
                            <strong>RAM:</strong> ${alert.total_ram_gb} GB
                        </p>
                    `}
                </div>
            `;
        });
        
        container.innerHTML = html;
    }

    setupTabListeners() {
        document.getElementById('computers-tab').addEventListener('click', () => {
            if (!document.getElementById('computersContainer').innerHTML.includes('computer-card')) {
                this.loadComputers();
            }
        });
        
        document.getElementById('disks-tab').addEventListener('click', () => {
            if (!document.getElementById('disksContainer').innerHTML.includes('table')) {
                this.loadDisks();
            }
        });
        
        document.getElementById('alerts-tab').addEventListener('click', () => {
            if (!document.getElementById('alertsContainer').innerHTML.includes('alert')) {
                this.loadAlerts();
            }
        });
    }

    startAutoRefresh() {
        // Refresh ogni 30 secondi
        this.refreshInterval = setInterval(() => {
            this.loadStatus();
        }, 30000);
    }

    stopAutoRefresh() {
        if (this.refreshInterval) {
            clearInterval(this.refreshInterval);
            this.refreshInterval = null;
        }
    }

    showError(message, containerId = null) {
        const errorHtml = `
            <div class="alert alert-danger" role="alert">
                <i class="fas fa-exclamation-triangle me-2"></i>
                ${message}
            </div>
        `;
        
        if (containerId) {
            document.getElementById(containerId).innerHTML = errorHtml;
        } else {
            console.error(message);
        }
    }
}

// Funzioni globali
function showLoading(show) {
    // Implementa loading globale se necessario
}

function refreshData() {
    console.log('🔄 Refresh manuale dati...');
    if (window.dashboard) {
        window.dashboard.loadInitialData();
        
        // Refresh anche i tab attivi
        const activeTab = document.querySelector('.nav-link.active').id;
        switch(activeTab) {
            case 'computers-tab':
                window.dashboard.loadComputers();
                break;
            case 'disks-tab':
                window.dashboard.loadDisks();
                break;
            case 'alerts-tab':
                window.dashboard.loadAlerts();
                break;
        }
    }
}

// Inizializza la dashboard quando il DOM è pronto
document.addEventListener('DOMContentLoaded', () => {
    window.dashboard = new MonitorITDashboard();
});

// Gestisci la chiusura della pagina
window.addEventListener('beforeunload', () => {
    if (window.dashboard) {
        window.dashboard.stopAutoRefresh();
    }
});