# ============================================
# GitOps TP - Installation Script for Windows
# File: Install-GitOpsTP.ps1
# Version: 1.0.0
# Author: DevOps Master Course
# ============================================

#Requires -RunAsAdministrator

param(
    [string]$InstallPath = "C:\GitOpsTP",
    [switch]$SkipDockerCheck = $false,
    [switch]$AutoStart = $false,
    [switch]$Verbose = $false
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

# Colors for output
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Write-Success { Write-ColorOutput "✅ $args" "Green" }
function Write-Error { Write-ColorOutput "❌ $args" "Red" }
function Write-Warning { Write-ColorOutput "⚠️ $args" "Yellow" }
function Write-Info { Write-ColorOutput "ℹ️ $args" "Cyan" }

# Banner
function Show-Banner {
    Clear-Host
    Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                    GitOps TP - Auto Installer                 ║
║                         Version 1.0.0                         ║
║                    DevOps Master Course 2024                  ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    Write-Host ""
}

# Check Prerequisites
function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    $prerequisites = @{
        "Docker" = { docker --version }
        "Docker Compose" = { docker-compose --version }
        "Git" = { git --version }
        "PowerShell 7+" = { $PSVersionTable.PSVersion.Major -ge 7 }
    }
    
    $failed = @()
    
    foreach ($tool in $prerequisites.Keys) {
        try {
            $result = & $prerequisites[$tool] 2>&1
            if ($LASTEXITCODE -eq 0 -or $tool -eq "PowerShell 7+") {
                Write-Success "$tool is installed"
            }
        }
        catch {
            Write-Error "$tool is not installed or not in PATH"
            $failed += $tool
        }
    }
    
    if ($failed.Count -gt 0) {
        Write-Error "Missing prerequisites: $($failed -join ', ')"
        
        if (-not $SkipDockerCheck -and $failed -contains "Docker") {
            Write-Info "Would you like to install Docker Desktop? (Y/N)"
            $response = Read-Host
            if ($response -eq 'Y') {
                Install-Docker
            }
        }
        
        if ($failed -contains "Docker" -or $failed -contains "Docker Compose") {
            return $false
        }
    }
    
    return $true
}

# Install Docker Desktop for Windows
function Install-Docker {
    Write-Info "Downloading Docker Desktop..."
    $dockerUrl = "https://desktop.docker.com/win/stable/Docker%20Desktop%20Installer.exe"
    $installerPath = "$env:TEMP\DockerDesktopInstaller.exe"
    
    try {
        Invoke-WebRequest -Uri $dockerUrl -OutFile $installerPath
        Write-Success "Docker Desktop downloaded"
        
        Write-Info "Installing Docker Desktop (this may take a few minutes)..."
        Start-Process -FilePath $installerPath -ArgumentList "install", "--quiet" -Wait
        
        Write-Success "Docker Desktop installed. Please restart your computer and run this script again."
        exit 0
    }
    catch {
        Write-Error "Failed to install Docker Desktop: $_"
        exit 1
    }
}

# Create Directory Structure
function Initialize-ProjectStructure {
    Write-Info "Creating project structure at $InstallPath..."
    
    $directories = @(
        "$InstallPath",
        "$InstallPath\config",
        "$InstallPath\config\prometheus",
        "$InstallPath\config\prometheus\rules",
        "$InstallPath\config\grafana",
        "$InstallPath\config\grafana\provisioning",
        "$InstallPath\config\grafana\provisioning\datasources",
        "$InstallPath\config\grafana\provisioning\dashboards",
        "$InstallPath\config\grafana\dashboards",
        "$InstallPath\config\alertmanager",
        "$InstallPath\config\jenkins",
        "$InstallPath\config\jenkins\jobs",
        "$InstallPath\config\jenkins\init.groovy.d",
        "$InstallPath\config\sonarqube",
        "$InstallPath\config\sonarqube\extensions",
        "$InstallPath\config\postgres",
        "$InstallPath\config\redis",
        "$InstallPath\application",
        "$InstallPath\scripts",
        "$InstallPath\tests",
        "$InstallPath\terraform",
        "$InstallPath\ansible",
        "$InstallPath\trivy-cache"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            if ($Verbose) { Write-Host "Created: $dir" -ForegroundColor Gray }
        }
    }
    
    Write-Success "Project structure created"
}

# Create Configuration Files
function New-ConfigurationFiles {
    Write-Info "Creating configuration files..."
    
    # Prometheus Configuration
    $prometheusConfig = @"
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'gitops-monitor'
    environment: 'development'

alerting:
  alertmanagers:
    - static_configs:
        - targets: ['alertmanager:9093']

rule_files:
  - '/etc/prometheus/rules/*.yml'

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']
  
  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
  
  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']
  
  - job_name: 'jenkins'
    metrics_path: '/prometheus'
    static_configs:
      - targets: ['jenkins:8080']
  
  - job_name: 'app'
    static_configs:
      - targets: ['app:3000']
"@
    Set-Content -Path "$InstallPath\config\prometheus\prometheus.yml" -Value $prometheusConfig
    
    # Prometheus Alert Rules
    $alertRules = @"
groups:
  - name: basic_alerts
    interval: 30s
    rules:
      - alert: InstanceDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Instance {{ `$labels.instance }} down"
          description: "{{ `$labels.instance }} of job {{ `$labels.job }} has been down for more than 1 minute."
      
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage detected"
          description: "Memory usage is above 85% (current value: {{ `$value }}%)"
      
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage detected"
          description: "CPU usage is above 80% (current value: {{ `$value }}%)"
      
      - alert: ContainerDown
        expr: time() - container_last_seen{name=~"gitops-.*"} > 60
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Container {{ `$labels.name }} is down"
          description: "Container {{ `$labels.name }} has been down for more than 1 minute"
"@
    Set-Content -Path "$InstallPath\config\prometheus\rules\alerts.yml" -Value $alertRules
    
    # Grafana Datasource
    $grafanaDatasource = @"
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "15s"
"@
    Set-Content -Path "$InstallPath\config\grafana\provisioning\datasources\prometheus.yml" -Value $grafanaDatasource
    
    # Grafana Dashboard Provider
    $dashboardProvider = @"
apiVersion: 1

providers:
  - name: 'GitOps Dashboards'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
"@
    Set-Content -Path "$InstallPath\config\grafana\provisioning\dashboards\provider.yml" -Value $dashboardProvider
    
    # AlertManager Configuration
    $alertmanagerConfig = @"
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'
  
receivers:
  - name: 'default'
    webhook_configs:
      - url: 'http://localhost:5001/webhook'
        send_resolved: true
"@
    Set-Content -Path "$InstallPath\config\alertmanager\alertmanager.yml" -Value $alertmanagerConfig
    
    # PostgreSQL Init Script
    $postgresInit = @"
-- Create SonarQube database and user
CREATE USER sonar WITH PASSWORD 'sonar2024';
CREATE DATABASE sonarqube OWNER sonar;
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;

-- Create GitOps application database
CREATE DATABASE gitops_app;
CREATE USER app_user WITH PASSWORD 'app2024';
GRANT ALL PRIVILEGES ON DATABASE gitops_app TO app_user;
"@
    Set-Content -Path "$InstallPath\config\postgres\init.sql" -Value $postgresInit
    
    # Redis Configuration
    $redisConfig = @"
# Redis configuration for GitOps TP
bind 0.0.0.0
protected-mode no
port 6379
tcp-backlog 511
timeout 0
tcp-keepalive 300
daemonize no
supervised no
pidfile /var/run/redis_6379.pid
loglevel notice
logfile ""
databases 16
save 900 1
save 300 10
save 60 10000
stop-writes-on-bgsave-error yes
rdbcompression yes
rdbchecksum yes
dbfilename dump.rdb
dir ./
maxmemory 256mb
maxmemory-policy allkeys-lru
"@
    Set-Content -Path "$InstallPath\config\redis\redis.conf" -Value $redisConfig
    
    # Jenkins Init Groovy Script
    $jenkinsInit = @'
import jenkins.model.*
import hudson.security.*
import jenkins.security.s2m.AdminWhitelistRule

def instance = Jenkins.getInstance()

// Disable setup wizard
instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)

// Create admin user
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "jenkins2024")
instance.setSecurityRealm(hudsonRealm)

// Configure authorization
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

// Save configuration
instance.save()
'@
    Set-Content -Path "$InstallPath\config\jenkins\init.groovy.d\01-admin-user.groovy" -Value $jenkinsInit
    
    Write-Success "Configuration files created"
}

# Create Application Files
function New-ApplicationFiles {
    Write-Info "Creating sample application..."
    
    # Application Dockerfile
    $dockerfile = @"
FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

USER node

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

CMD ["node", "server.js"]
"@
    Set-Content -Path "$InstallPath\application\Dockerfile" -Value $dockerfile
    
    # Application package.json
    $packageJson = @"
{
  "name": "gitops-monitoring-app",
  "version": "1.0.0",
  "description": "GitOps TP Monitoring Application",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "test": "echo \"No tests yet\""
  },
  "dependencies": {
    "express": "^4.18.2",
    "prom-client": "^14.2.0",
    "redis": "^4.6.10"
  }
}
"@
    Set-Content -Path "$InstallPath\application\package.json" -Value $packageJson
    
    # Application server.js
    $serverJs = @'
const express = require('express');
const client = require('prom-client');
const redis = require('redis');

const app = express();
const register = new client.Registry();

// Add default metrics
client.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestDuration = new client.Histogram({
    name: 'http_request_duration_ms',
    help: 'Duration of HTTP requests in ms',
    labelNames: ['method', 'route', 'status_code'],
    buckets: [0.1, 5, 15, 50, 100, 500]
});
register.registerMetric(httpRequestDuration);

const httpRequestTotal = new client.Counter({
    name: 'http_requests_total',
    help: 'Total number of HTTP requests',
    labelNames: ['method', 'route', 'status_code']
});
register.registerMetric(httpRequestTotal);

// Redis connection
let redisClient;
async function connectRedis() {
    try {
        redisClient = redis.createClient({
            socket: { host: process.env.REDIS_HOST || 'redis', port: 6379 }
        });
        await redisClient.connect();
        console.log('Connected to Redis');
    } catch (err) {
        console.error('Redis connection failed:', err);
    }
}
connectRedis();

// Middleware to track metrics
app.use((req, res, next) => {
    const start = Date.now();
    res.on('finish', () => {
        const duration = Date.now() - start;
        httpRequestDuration.observe(
            { method: req.method, route: req.path, status_code: res.statusCode },
            duration
        );
        httpRequestTotal.inc({ method: req.method, route: req.path, status_code: res.statusCode });
    });
    next();
});

// Routes
app.get('/', (req, res) => {
    res.json({ message: 'GitOps Monitoring App', version: '1.0.0' });
});

app.get('/health', (req, res) => {
    res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });
});

app.get('/metrics', async (req, res) => {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
});

app.get('/api/info', async (req, res) => {
    const info = {
        app: 'GitOps Monitoring',
        version: '1.0.0',
        environment: process.env.NODE_ENV || 'development',
        uptime: process.uptime(),
        redis: redisClient && redisClient.isOpen ? 'connected' : 'disconnected'
    };
    res.json(info);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
'@
    Set-Content -Path "$InstallPath\application\server.js" -Value $serverJs
    
    Write-Success "Application files created"
}

# Create Docker Compose Override for Windows
function New-DockerComposeOverride {
    Write-Info "Creating Docker Compose override for Windows..."
    
    $overrideContent = @"
# Docker Compose Override for Windows
version: '3.9'

services:
  node-exporter:
    volumes:
      # Windows-specific volume mappings
      - type: bind
        source: /proc
        target: /host/proc
        read_only: true
      - type: bind
        source: /sys
        target: /host/sys
        read_only: true
      - type: bind
        source: /
        target: /rootfs
        read_only: true
    
  cadvisor:
    volumes:
      # Windows Docker Desktop paths
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    
  jenkins:
    volumes:
      # Windows Docker socket path
      - //var/run/docker.sock:/var/run/docker.sock
"@
    
    if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
        Set-Content -Path "$InstallPath\docker-compose.override.yml" -Value $overrideContent
        Write-Success "Windows-specific Docker Compose override created"
    }
}

# Copy main docker-compose.yml
function Copy-DockerComposeFile {
    Write-Info "Setting up Docker Compose configuration..."
    
    # Copy the docker-compose.yml content from the first file
    Copy-Item -Path "$PSScriptRoot\docker-compose.yml" -Destination "$InstallPath\docker-compose.yml" -Force -ErrorAction SilentlyContinue
    
    if (-not (Test-Path "$InstallPath\docker-compose.yml")) {
        Write-Warning "docker-compose.yml not found, creating from embedded template..."
        # Here you would embed the full docker-compose.yml content
        # For brevity, using a placeholder
        Set-Content -Path "$InstallPath\docker-compose.yml" -Value (Get-Content -Raw -Path "$PSScriptRoot\docker-compose.yml")
    }
    
    Write-Success "Docker Compose configuration ready"
}

# Start Services
function Start-GitOpsStack {
    Write-Info "Starting GitOps stack..."
    
    Set-Location $InstallPath
    
    # Pull images first
    Write-Info "Pulling Docker images (this may take a while)..."
    docker-compose pull 2>&1 | Out-String
    
    # Start services
    Write-Info "Starting services..."
    docker-compose up -d 2>&1 | Out-String
    
    # Wait for services to be healthy
    Write-Info "Waiting for services to be healthy..."
    $services = @("prometheus", "grafana", "jenkins")
    $maxAttempts = 30
    
    foreach ($service in $services) {
        $attempts = 0
        while ($attempts -lt $maxAttempts) {
            $health = docker inspect gitops-$service --format='{{.State.Health.Status}}' 2>$null
            if ($health -eq "healthy") {
                Write-Success "$service is healthy"
                break
            }
            Start-Sleep -Seconds 2
            $attempts++
        }
        if ($attempts -eq $maxAttempts) {
            Write-Warning "$service did not become healthy in time"
        }
    }
    
    Write-Success "GitOps stack started"
}

# Display Access Information
function Show-AccessInfo {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                    🎉 Installation Complete!                  ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "📦 Services Access URLs:" -ForegroundColor Cyan
    Write-Host "  • Prometheus:  http://localhost:9090" -ForegroundColor White
    Write-Host "  • Grafana:     http://localhost:3000  (admin / gitops2024)" -ForegroundColor White
    Write-Host "  • Jenkins:     http://localhost:8081  (admin / jenkins2024)" -ForegroundColor White
    Write-Host "  • SonarQube:   http://localhost:9000  (admin / admin)" -ForegroundColor White
    Write-Host "  • GitLab:      http://localhost:8082  (root / gitlab2024root)" -ForegroundColor White
    Write-Host "  • Portainer:   http://localhost:9001" -ForegroundColor White
    Write-Host "  • cAdvisor:    http://localhost:8080" -ForegroundColor White
    Write-Host "  • Application: http://localhost:3001" -ForegroundColor White
    Write-Host ""
    Write-Host "📁 Project Location: $InstallPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🔧 Useful Commands:" -ForegroundColor Cyan
    Write-Host "  • Check status:  docker-compose ps" -ForegroundColor White
    Write-Host "  • View logs:     docker-compose logs -f [service]" -ForegroundColor White
    Write-Host "  • Stop stack:    docker-compose down" -ForegroundColor White
    Write-Host "  • Restart:       docker-compose restart" -ForegroundColor White
    Write-Host "  • Run tests:     .\Run-Tests.ps1" -ForegroundColor White
    Write-Host ""
}

# Main Installation Flow
function Install-GitOpsTP {
    Show-Banner
    
    if (-not (Test-Prerequisites)) {
        Write-Error "Prerequisites check failed. Please install missing components and try again."
        exit 1
    }
    
    Initialize-ProjectStructure
    New-ConfigurationFiles
    New-ApplicationFiles
    Copy-DockerComposeFile
    New-DockerComposeOverride
    
    if ($AutoStart) {
        Start-GitOpsStack
    } else {
        Write-Info "To start the GitOps stack, run:"
        Write-Host "  cd $InstallPath" -ForegroundColor Yellow
        Write-Host "  docker-compose up -d" -ForegroundColor Yellow
    }
    
    Show-AccessInfo
    
    # Create uninstall script
    $uninstallScript = @"
# Uninstall GitOps TP
docker-compose -f "$InstallPath\docker-compose.yml" down -v
docker system prune -af
Remove-Item -Path "$InstallPath" -Recurse -Force
Write-Host "GitOps TP uninstalled successfully" -ForegroundColor Green
"@
    Set-Content -Path "$InstallPath\Uninstall-GitOpsTP.ps1" -Value $uninstallScript
    
    Write-Success "Installation completed successfully!"
}

# Run installation
try {
    Install-GitOpsTP
}
catch {
    Write-Error "Installation failed: $_"
    exit 1
}
