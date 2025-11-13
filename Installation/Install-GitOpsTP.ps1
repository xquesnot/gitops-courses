# ============================================
# GitOps TP - Complete Setup Script for Windows
# File: Setup-GitOpsEnvironment.ps1
# Version: 2.0.0 - Fixed and Unified
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

# ==============================================
# HELPER FUNCTIONS
# ==============================================

# Colors for output
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Write-Success { Write-ColorOutput "✅ $args" "Green" }
function Write-Error { Write-ColorOutput "❌ $args" "Red" }
function Write-Warning { Write-ColorOutput "⚠️ $args" "Yellow" }
function Write-Info { Write-ColorOutput "ℹ️ $args" "Cyan" }

# Banner Function (DÉFINITION AJOUTÉE ICI)
function Show-Banner {
    Clear-Host
    Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║                 GitOps TP - Complete Setup                    ║
║                         Version 2.0.0                         ║
║                    DevOps Master Course 2024                  ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    Write-Host ""
}

# ==============================================
# PREREQUISITES CHECKING
# ==============================================

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

# ==============================================
# PROJECT STRUCTURE CREATION
# ==============================================

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

# ==============================================
# DOCKER-COMPOSE.YML CREATION
# ==============================================

function New-DockerComposeFile {
    Write-Info "Creating Docker Compose configuration..."
    
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
    driver: local
  grafana_data:
    driver: local
  jenkins_data:
    driver: local
  gitlab_config:
    driver: local
  gitlab_logs:
    driver: local
  gitlab_data:
    driver: local
  sonarqube_data:
    driver: local
  sonarqube_logs:
    driver: local
  sonarqube_extensions:
    driver: local
  postgres_data:
    driver: local
  trivy_cache:
    driver: local
  portainer_data:
    driver: local

services:
  # ============================================
  # MONITORING STACK
  # ============================================
  
  prometheus:
    image: prom/prometheus:v2.48.0
    container_name: gitops-prometheus
    hostname: prometheus
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
      - '--web.console.libraries=/usr/share/prometheus/console_libraries'
      - '--web.console.templates=/usr/share/prometheus/consoles'
      - '--web.enable-lifecycle'
      - '--storage.tsdb.retention.time=30d'
    labels:
      - "monitoring.service=prometheus"
      - "monitoring.type=timeseries"
    healthcheck:
      test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:9090/-/healthy || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  grafana:
    image: grafana/grafana:10.2.2
    container_name: gitops-grafana
    hostname: grafana
    restart: unless-stopped
    networks:
      gitops-network:
        ipv4_address: 172.20.0.11
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./config/grafana/provisioning:/etc/grafana/provisioning:ro
      - ./config/grafana/dashboards:/var/lib/grafana/dashboards:ro
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=gitops2024
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource,redis-datasource
      - GF_SERVER_ROOT_URL=http://localhost:3000
    depends_on:
      - prometheus
    labels:
      - "monitoring.service=grafana"
      - "monitoring.type=visualization"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/api/health || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3

  alertmanager:
    image: prom/alertmanager:v0.26.0
    container_name: gitops-alertmanager
    hostname: alertmanager
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
      - '--storage.path=/alertmanager'
    labels:
      - "monitoring.service=alertmanager"
      - "monitoring.type=alerting"

  # CI/CD Stack
  jenkins:
    image: jenkins/jenkins:2.426.1-lts
    container_name: gitops-jenkins
    hostname: jenkins
    restart: unless-stopped
    networks:
      gitops-network:
        ipv4_address: 172.20.0.20
    ports:
      - "8081:8080"
      - "50000:50000"
    volumes:
      - jenkins_data:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
      - ./config/jenkins/jobs:/var/jenkins_home/jobs:ro
      - ./config/jenkins/init.groovy.d:/usr/share/jenkins/ref/init.groovy.d:ro
    environment:
      - JENKINS_OPTS=--prefix=/
      - JAVA_OPTS=-Duser.timezone=Europe/Paris -Djenkins.install.runSetupWizard=false
      - JENKINS_ADMIN_ID=admin
      - JENKINS_ADMIN_PASSWORD=jenkins2024
    user: root
    labels:
      - "cicd.service=jenkins"
      - "cicd.type=automation"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080/login || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 5
      start_period: 60s

  # Node Exporter
  node-exporter:
    image: prom/node-exporter:v1.7.0
    container_name: gitops-node-exporter
    hostname: node-exporter
    restart: unless-stopped
    networks:
      gitops-network:
        ipv4_address: 172.20.0.13
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    labels:
      - "monitoring.service=node-exporter"
      - "monitoring.type=metrics-collector"

  # Redis Cache
  redis:
    image: redis:7-alpine
    container_name: gitops-redis
    hostname: redis
    restart: unless-stopped
    networks:
      gitops-network:
        ipv4_address: 172.20.0.41
    ports:
      - "6379:6379"
    volumes:
      - ./config/redis/redis.conf:/usr/local/etc/redis/redis.conf:ro
    command: redis-server /usr/local/etc/redis/redis.conf
    labels:
      - "storage.service=redis"
      - "storage.type=cache"
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
    hostname: app
    restart: unless-stopped
    networks:
      gitops-network:
        ipv4_address: 172.20.0.50
    ports:
      - "3001:3000"
    environment:
      - NODE_ENV=production
      - PROMETHEUS_ENABLED=true
      - REDIS_HOST=redis
      - REDIS_PORT=6379
    depends_on:
      - redis
    labels:
      - "app.service=monitoring-app"
      - "app.version=1.0.0"
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
'@
    
    Set-Content -Path "$InstallPath\docker-compose.yml" -Value $dockerComposeContent
    Write-Success "Docker Compose configuration created"
}

# ==============================================
# CONFIGURATION FILES CREATION
# ==============================================

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

# ==============================================
# APPLICATION FILES CREATION
# ==============================================

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

# ==============================================
# JENKINSFILE CREATION
# ==============================================

function New-Jenkinsfile {
    Write-Info "Creating Jenkinsfile..."
    
    $jenkinsfileContent = @'
pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'docker.io'
        IMAGE_NAME = 'gitops-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Build') {
            steps {
                script {
                    docker.build("${IMAGE_NAME}:${IMAGE_TAG}", "./application")
                }
            }
        }
        
        stage('Test') {
            steps {
                script {
                    docker.run("${IMAGE_NAME}:${IMAGE_TAG}", "npm test")
                }
            }
        }
        
        stage('Security Scan') {
            steps {
                script {
                    sh "trivy image --severity HIGH,CRITICAL ${IMAGE_NAME}:${IMAGE_TAG}"
                }
            }
        }
        
        stage('Deploy') {
            steps {
                script {
                    sh "docker-compose up -d app"
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed!'
        }
    }
}
'@
    
    Set-Content -Path "$InstallPath\Jenkinsfile" -Value $jenkinsfileContent
    Write-Success "Jenkinsfile created"
}

# ==============================================
# README CREATION
# ==============================================

function New-README {
    Write-Info "Creating README..."
    
    $readmeContent = @"
# GitOps TP - Monitoring Stack

## 📦 Services Included

- **Prometheus** (9090): Time-series metrics database
- **Grafana** (3000): Visualization and dashboards
- **Jenkins** (8081): CI/CD automation server
- **AlertManager** (9093): Alert management
- **Node Exporter** (9100): System metrics
- **Redis** (6379): Cache and queue
- **Application** (3001): Sample monitoring app

## 🚀 Quick Start

\`\`\`powershell
# Start all services
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f [service-name]
\`\`\`

## 🔐 Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Grafana | admin | gitops2024 |
| Jenkins | admin | jenkins2024 |

## 📊 Monitoring

1. Access Grafana at http://localhost:3000
2. Prometheus datasource is pre-configured
3. Import dashboards from config/grafana/dashboards/

## 🔧 Configuration

All configuration files are in the \`config/\` directory:
- \`prometheus/\`: Prometheus configuration and rules
- \`grafana/\`: Grafana provisioning
- \`jenkins/\`: Jenkins initialization scripts
- \`alertmanager/\`: Alert routing configuration

## 📝 Testing

Run the grading script:
\`\`\`powershell
.\Grade-GitOpsTP.ps1
\`\`\`

## 🛑 Stopping Services

\`\`\`powershell
# Stop all services
docker-compose down

# Stop and remove volumes
docker-compose down -v
\`\`\`
"@
    
    Set-Content -Path "$InstallPath\README.md" -Value $readmeContent
    Write-Success "README created"
}

# ==============================================
# SERVICES STARTUP
# ==============================================

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

# ==============================================
# ACCESS INFORMATION DISPLAY
# ==============================================

function Show-AccessInfo {
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                    🎉 Installation Complete!                  ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "📦 Services Access URLs:" -ForegroundColor Cyan
    Write-Host "  • Prometheus:    http://localhost:9090" -ForegroundColor White
    Write-Host "  • Grafana:       http://localhost:3000  (admin / gitops2024)" -ForegroundColor White
    Write-Host "  • Jenkins:       http://localhost:8081  (admin / jenkins2024)" -ForegroundColor White
    Write-Host "  • AlertManager:  http://localhost:9093" -ForegroundColor White
    Write-Host "  • Node Exporter: http://localhost:9100/metrics" -ForegroundColor White
    Write-Host "  • Application:   http://localhost:3001" -ForegroundColor White
    Write-Host ""
    Write-Host "📁 Project Location: $InstallPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "🔧 Useful Commands:" -ForegroundColor Cyan
    Write-Host "  • Check status:  docker-compose ps" -ForegroundColor White
    Write-Host "  • View logs:     docker-compose logs -f [service]" -ForegroundColor White
    Write-Host "  • Stop stack:    docker-compose down" -ForegroundColor White
    Write-Host "  • Restart:       docker-compose restart" -ForegroundColor White
    Write-Host "  • Run tests:     .\Grade-GitOpsTP.ps1" -ForegroundColor White
    Write-Host ""
    Write-Host "📚 Documentation: Check README.md in $InstallPath" -ForegroundColor Yellow
    Write-Host ""
}

# ==============================================
# MAIN INSTALLATION FLOW
# ==============================================

function Install-GitOpsEnvironment {
    Show-Banner
    
    # Check prerequisites
    if (-not (Test-Prerequisites)) {
        Write-Error "Prerequisites check failed. Please install missing components and try again."
        Write-Host ""
        Write-Host "For Docker installation, visit: https://docs.docker.com/desktop/install/windows-install/" -ForegroundColor Yellow
        exit 1
    }
    
    # Create project structure
    Initialize-ProjectStructure
    
    # Create all configuration files
    New-DockerComposeFile
    New-ConfigurationFiles
    New-ApplicationFiles
    New-Jenkinsfile
    New-README
    
    # Copy grading script if it exists
    if (Test-Path "$PSScriptRoot\Grade-GitOpsTP.ps1") {
        Copy-Item -Path "$PSScriptRoot\Grade-GitOpsTP.ps1" -Destination "$InstallPath\Grade-GitOpsTP.ps1" -Force
        Write-Success "Grading script copied"
    }
    
    # Create uninstall script
    $uninstallScript = @"
# Uninstall GitOps TP
Write-Host "Stopping and removing GitOps TP..." -ForegroundColor Yellow
docker-compose -f "$InstallPath\docker-compose.yml" down -v
docker system prune -af
Remove-Item -Path "$InstallPath" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "GitOps TP uninstalled successfully" -ForegroundColor Green
"@
    Set-Content -Path "$InstallPath\Uninstall-GitOpsTP.ps1" -Value $uninstallScript
    
    # Start services if requested
    if ($AutoStart) {
        Start-GitOpsStack
    } else {
        Write-Info "To start the GitOps stack, run:"
        Write-Host "  cd $InstallPath" -ForegroundColor Yellow
        Write-Host "  docker-compose up -d" -ForegroundColor Yellow
    }
    
    # Show access information
    Show-AccessInfo
    
    Write-Success "Installation completed successfully!"
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Cyan
    Write-Host "1. cd $InstallPath" -ForegroundColor White
    Write-Host "2. docker-compose up -d" -ForegroundColor White
    Write-Host "3. Access services using the URLs above" -ForegroundColor White
}

# ==============================================
# SCRIPT EXECUTION
# ==============================================

try {
    Install-GitOpsEnvironment
}
catch {
    Write-Error "Installation failed: $_"
    Write-Host ""
    Write-Host "Stack trace:" -ForegroundColor Yellow
    Write-Host $_.Exception.StackTrace -ForegroundColor Gray
    exit 1
}
