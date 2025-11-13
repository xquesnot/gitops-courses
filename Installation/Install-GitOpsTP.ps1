# ============================================
# GitOps TP - Installation Script (Fixed Version 3.0)
# File: Install-GitOps-Fixed.ps1
# Author: DevOps Master Course
# ============================================

[CmdletBinding()]
param(
    [string]$InstallPath = "C:\GitOpsTP",
    [switch]$SkipDockerCheck = $false,
    [switch]$AutoStart = $false,
    [switch]$Debug = $false
)

# Set error handling
$ErrorActionPreference = "Stop"
$ProgressPreference = 'SilentlyContinue'

# ==============================================
# STEP 1: DEFINE ALL FUNCTIONS FIRST
# ==============================================

# Display banner without function call
Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                 GitOps TP - Installation Script               ║" -ForegroundColor Cyan
Write-Host "║                         Version 3.0                           ║" -ForegroundColor Cyan
Write-Host "║                    DevOps Master Course 2024                  ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Helper functions for colored output
function Write-Success { Write-Host "✅ $($args -join ' ')" -ForegroundColor Green }
function Write-Error { Write-Host "❌ $($args -join ' ')" -ForegroundColor Red }
function Write-Warning { Write-Host "⚠️ $($args -join ' ')" -ForegroundColor Yellow }
function Write-Info { Write-Host "ℹ️ $($args -join ' ')" -ForegroundColor Cyan }

# ==============================================
# CHECK PREREQUISITES
# ==============================================

Write-Info "Starting GitOps TP installation..."
Write-Info "Install path: $InstallPath"

# Check if running as administrator
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "This script must be run as Administrator."
    Write-Warning "Please right-click on PowerShell and select 'Run as Administrator'"
    exit 1
}

# Check Docker
Write-Info "Checking Docker installation..."
try {
    $dockerVersion = docker --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker is installed: $dockerVersion"
    } else {
        throw "Docker not working properly"
    }
}
catch {
    Write-Error "Docker is not installed or not running"
    
    if (-not $SkipDockerCheck) {
        Write-Warning "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop/"
        Write-Info "After installing Docker, restart your computer and run this script again."
        
        $response = Read-Host "Do you want to open the Docker download page? (Y/N)"
        if ($response -eq 'Y') {
            Start-Process "https://www.docker.com/products/docker-desktop/"
        }
        exit 1
    }
}

# Check Docker Compose
Write-Info "Checking Docker Compose..."
try {
    $composeVersion = docker-compose --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Docker Compose is installed: $composeVersion"
    }
}
catch {
    Write-Warning "Docker Compose not found as standalone, checking if it's included in Docker..."
    try {
        $composeVersion = docker compose version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker Compose (plugin) is installed: $composeVersion"
        }
    }
    catch {
        Write-Error "Docker Compose is not installed"
        exit 1
    }
}

# ==============================================
# CREATE PROJECT STRUCTURE
# ==============================================

Write-Info "Creating project structure..."

# Create main directory
if (-not (Test-Path $InstallPath)) {
    New-Item -ItemType Directory -Path $InstallPath -Force | Out-Null
    Write-Success "Created main directory: $InstallPath"
} else {
    Write-Info "Directory already exists: $InstallPath"
}

# Create subdirectories
$directories = @(
    "config\prometheus",
    "config\prometheus\rules",
    "config\grafana\provisioning\datasources",
    "config\grafana\provisioning\dashboards",
    "config\grafana\dashboards",
    "config\alertmanager",
    "config\jenkins\init.groovy.d",
    "config\redis",
    "application",
    "scripts",
    "tests"
)

foreach ($dir in $directories) {
    $fullPath = Join-Path $InstallPath $dir
    if (-not (Test-Path $fullPath)) {
        New-Item -ItemType Directory -Path $fullPath -Force | Out-Null
        if ($Debug) { Write-Host "  Created: $fullPath" -ForegroundColor Gray }
    }
}

Write-Success "Project structure created"

# ==============================================
# CREATE DOCKER-COMPOSE.YML
# ==============================================

Write-Info "Creating docker-compose.yml..."

$dockerComposeContent = @'
version: '3.9'

networks:
  gitops-network:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16

volumes:
  prometheus_data:
  grafana_data:
  jenkins_data:

services:
  # Prometheus
  prometheus:
    image: prom/prometheus:latest
    container_name: gitops-prometheus
    restart: unless-stopped
    networks:
      gitops-network:
        ipv4_address: 172.20.0.10
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus:/etc/prometheus:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.enable-lifecycle'
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Grafana
  grafana:
    image: grafana/grafana:latest
    container_name: gitops-grafana
    restart: unless-stopped
    networks:
      gitops-network:
        ipv4_address: 172.20.0.11
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./config/grafana/provisioning:/etc/grafana/provisioning:ro
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=gitops2024
    depends_on:
      - prometheus
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/api/health || exit 1"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Jenkins
  jenkins:
    image: jenkins/jenkins:lts
    container_name: gitops-jenkins
    restart: unless-stopped
    networks:
      gitops-network:
        ipv4_address: 172.20.0.20
    ports:
      - "8081:8080"
      - "50000:50000"
    volumes:
      - jenkins_data:/var/jenkins_home
      - //var/run/docker.sock:/var/run/docker.sock
    environment:
      - JENKINS_OPTS=--prefix=/
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false
    user: root
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080/login || exit 1"]
      interval: 60s
      timeout: 10s
      retries: 5

  # Node Exporter
  node-exporter:
    image: prom/node-exporter:latest
    container_name: gitops-node-exporter
    restart: unless-stopped
    networks:
      gitops-network:
        ipv4_address: 172.20.0.13
    ports:
      - "9100:9100"
    command:
      - '--path.rootfs=/host'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/host:ro

  # AlertManager
  alertmanager:
    image: prom/alertmanager:latest
    container_name: gitops-alertmanager
    restart: unless-stopped
    networks:
      gitops-network:
        ipv4_address: 172.20.0.12
    ports:
      - "9093:9093"
    volumes:
      - ./config/alertmanager:/etc/alertmanager:ro
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'

  # Redis
  redis:
    image: redis:alpine
    container_name: gitops-redis
    restart: unless-stopped
    networks:
      gitops-network:
        ipv4_address: 172.20.0.41
    ports:
      - "6379:6379"
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Application
  app:
    build:
      context: ./application
      dockerfile: Dockerfile
    container_name: gitops-app
    restart: unless-stopped
    networks:
      gitops-network:
        ipv4_address: 172.20.0.50
    ports:
      - "3001:3000"
    environment:
      - NODE_ENV=production
      - REDIS_HOST=redis
    depends_on:
      - redis
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
'@

$dockerComposePath = Join-Path $InstallPath "docker-compose.yml"
Set-Content -Path $dockerComposePath -Value $dockerComposeContent -Encoding UTF8
Write-Success "docker-compose.yml created"

# ==============================================
# CREATE PROMETHEUS CONFIG
# ==============================================

Write-Info "Creating Prometheus configuration..."

$prometheusConfig = @'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

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
  
  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']
  
  - job_name: 'jenkins'
    static_configs:
      - targets: ['jenkins:8080']
  
  - job_name: 'app'
    static_configs:
      - targets: ['app:3000']
'@

$prometheusConfigPath = Join-Path $InstallPath "config\prometheus\prometheus.yml"
Set-Content -Path $prometheusConfigPath -Value $prometheusConfig -Encoding UTF8
Write-Success "Prometheus configuration created"

# ==============================================
# CREATE ALERT RULES
# ==============================================

Write-Info "Creating alert rules..."

$alertRules = @'
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
          summary: "Instance {{ $labels.instance }} down"
          description: "{{ $labels.instance }} has been down for more than 1 minute."
'@

$alertRulesPath = Join-Path $InstallPath "config\prometheus\rules\alerts.yml"
Set-Content -Path $alertRulesPath -Value $alertRules -Encoding UTF8
Write-Success "Alert rules created"

# ==============================================
# CREATE GRAFANA DATASOURCE
# ==============================================

Write-Info "Creating Grafana datasource..."

$grafanaDatasource = @'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
'@

$datasourcePath = Join-Path $InstallPath "config\grafana\provisioning\datasources\prometheus.yml"
Set-Content -Path $datasourcePath -Value $grafanaDatasource -Encoding UTF8
Write-Success "Grafana datasource created"

# ==============================================
# CREATE ALERTMANAGER CONFIG
# ==============================================

Write-Info "Creating AlertManager configuration..."

$alertmanagerConfig = @'
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'default'

receivers:
  - name: 'default'
'@

$alertmanagerPath = Join-Path $InstallPath "config\alertmanager\alertmanager.yml"
Set-Content -Path $alertmanagerPath -Value $alertmanagerConfig -Encoding UTF8
Write-Success "AlertManager configuration created"

# ==============================================
# CREATE APPLICATION FILES
# ==============================================

Write-Info "Creating application files..."

# Dockerfile
$dockerfile = @'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
'@

$dockerfilePath = Join-Path $InstallPath "application\Dockerfile"
Set-Content -Path $dockerfilePath -Value $dockerfile -Encoding UTF8

# package.json
$packageJson = @'
{
  "name": "gitops-app",
  "version": "1.0.0",
  "description": "GitOps monitoring app",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2",
    "prom-client": "^14.2.0",
    "redis": "^4.6.10"
  }
}
'@

$packagePath = Join-Path $InstallPath "application\package.json"
Set-Content -Path $packagePath -Value $packageJson -Encoding UTF8

# server.js
$serverJs = @'
const express = require('express');
const client = require('prom-client');
const app = express();
const register = new client.Registry();

// Metrics
client.collectDefaultMetrics({ register });

const httpRequests = new client.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
  registers: [register]
});

// Middleware
app.use((req, res, next) => {
  res.on('finish', () => {
    httpRequests.inc({
      method: req.method,
      route: req.path,
      status: res.statusCode
    });
  });
  next();
});

// Routes
app.get('/', (req, res) => {
  res.json({ message: 'GitOps App', version: '1.0.0' });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

app.get('/metrics', async (req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
'@

$serverPath = Join-Path $InstallPath "application\server.js"
Set-Content -Path $serverPath -Value $serverJs -Encoding UTF8

Write-Success "Application files created"

# ==============================================
# CREATE README
# ==============================================

Write-Info "Creating README..."

$readme = @"
# GitOps TP - Monitoring Stack

## Quick Start

\`\`\`powershell
# Start services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
\`\`\`

## Services

- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000 (admin/gitops2024)
- **Jenkins**: http://localhost:8081
- **AlertManager**: http://localhost:9093
- **Application**: http://localhost:3001

## Stop Services

\`\`\`powershell
docker-compose down
docker-compose down -v  # Remove volumes
\`\`\`
"@

$readmePath = Join-Path $InstallPath "README.md"
Set-Content -Path $readmePath -Value $readme -Encoding UTF8
Write-Success "README created"

# ==============================================
# COPY GRADING SCRIPT
# ==============================================

$gradingScriptSource = Join-Path $PSScriptRoot "Grade-GitOpsTP.ps1"
$gradingScriptDest = Join-Path $InstallPath "Grade-GitOpsTP.ps1"

if (Test-Path $gradingScriptSource) {
    Copy-Item -Path $gradingScriptSource -Destination $gradingScriptDest -Force
    Write-Success "Grading script copied"
} else {
    Write-Warning "Grading script not found in source directory"
}

# ==============================================
# START SERVICES (if requested)
# ==============================================

if ($AutoStart) {
    Write-Info "Starting Docker services..."
    
    Set-Location $InstallPath
    
    # Pull images
    Write-Info "Pulling Docker images (this may take a while)..."
    $pullResult = docker-compose pull 2>&1
    
    # Start services
    Write-Info "Starting services..."
    $upResult = docker-compose up -d 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Services started successfully"
        
        # Wait a bit for services to initialize
        Write-Info "Waiting for services to initialize..."
        Start-Sleep -Seconds 10
        
        # Check status
        docker-compose ps
    } else {
        Write-Error "Failed to start services"
        Write-Host $upResult
    }
}

# ==============================================
# DISPLAY FINAL INFORMATION
# ==============================================

Write-Host ""
Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                    ✅ Installation Complete!                  ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

Write-Host "📁 Project Location: $InstallPath" -ForegroundColor Yellow
Write-Host ""

Write-Host "🌐 Service URLs:" -ForegroundColor Cyan
Write-Host "   • Prometheus:  http://localhost:9090" -ForegroundColor White
Write-Host "   • Grafana:     http://localhost:3000 (admin/gitops2024)" -ForegroundColor White
Write-Host "   • Jenkins:     http://localhost:8081" -ForegroundColor White
Write-Host "   • AlertManager: http://localhost:9093" -ForegroundColor White
Write-Host "   • Application: http://localhost:3001" -ForegroundColor White
Write-Host ""

if (-not $AutoStart) {
    Write-Host "📦 To start the services:" -ForegroundColor Yellow
    Write-Host "   cd $InstallPath" -ForegroundColor White
    Write-Host "   docker-compose up -d" -ForegroundColor White
    Write-Host ""
}

Write-Host "🛠️ Useful Commands:" -ForegroundColor Cyan
Write-Host "   docker-compose ps          # Check status" -ForegroundColor White
Write-Host "   docker-compose logs -f     # View logs" -ForegroundColor White
Write-Host "   docker-compose down        # Stop services" -ForegroundColor White
Write-Host "   docker-compose down -v     # Stop and remove volumes" -ForegroundColor White
Write-Host ""

Write-Host "📊 To test your setup:" -ForegroundColor Cyan
Write-Host "   cd $InstallPath" -ForegroundColor White
Write-Host "   .\Grade-GitOpsTP.ps1       # Run grading script" -ForegroundColor White
Write-Host ""

Write-Success "GitOps TP installation completed successfully!"
