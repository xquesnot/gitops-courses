# ============================================
# GitOps TP - Installation Script (Fixed YAML Version)
# File: Install-GitOpsTP-Final.ps1
# Version: 5.0 - YAML Fixed
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

function Write-Success { 
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green 
}

function Write-Error { 
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red 
}

function Write-Warning { 
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor Yellow 
}

function Write-Info { 
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan 
}

# Banner
function Show-Banner {
    Clear-Host
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "                  GitOps TP - Installation Script               " -ForegroundColor Cyan
    Write-Host "                         Version 5.0                            " -ForegroundColor Cyan
    Write-Host "                    DevOps Master Course 2024                   " -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
}

# ==============================================
# PREREQUISITES CHECKING
# ==============================================

function Test-Prerequisites {
    Write-Info "Checking prerequisites..."
    
    $allGood = $true
    
    # Check Docker
    try {
        $dockerVersion = docker --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker is installed"
        } else {
            throw "Docker error"
        }
    }
    catch {
        Write-Error "Docker is not installed or not running"
        $allGood = $false
    }
    
    # Check Docker Compose
    try {
        $composeVersion = docker-compose --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Docker Compose is installed"
        }
    }
    catch {
        # Try Docker Compose as plugin
        try {
            $composeVersion = docker compose version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Success "Docker Compose (plugin) is installed"
            }
        }
        catch {
            Write-Error "Docker Compose is not installed"
            $allGood = $false
        }
    }
    
    # Check Git
    try {
        $gitVersion = git --version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Git is installed"
        }
    }
    catch {
        Write-Warning "Git is not installed (optional)"
    }
    
    return $allGood
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
        "$InstallPath\config\jenkins\init.groovy.d",
        "$InstallPath\config\redis",
        "$InstallPath\application",
        "$InstallPath\scripts",
        "$InstallPath\tests"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            if ($Verbose) { Write-Host "  Created: $dir" -ForegroundColor Gray }
        }
    }
    
    Write-Success "Project structure created"
}

# ==============================================
# DOCKER-COMPOSE.YML CREATION
# ==============================================

function New-DockerComposeFile {
    Write-Info "Creating Docker Compose configuration..."
    
    # Use single quotes to prevent PowerShell from interpreting the content
    $dockerComposeContent = 'version: "3.9"

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

services:
  # Prometheus
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
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"
      - "--web.enable-lifecycle"
      - "--storage.tsdb.retention.time=30d"
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 5s
      retries: 3

  # Grafana
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
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=gitops2024
      - GF_SERVER_ROOT_URL=http://localhost:3000
    depends_on:
      - prometheus
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/api/health || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3

  # AlertManager
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
      - "--config.file=/etc/alertmanager/alertmanager.yml"
      - "--storage.path=/alertmanager"

  # Jenkins
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
      - //var/run/docker.sock:/var/run/docker.sock
    environment:
      - JENKINS_OPTS=--prefix=/
      - JAVA_OPTS=-Djenkins.install.runSetupWizard=false
      - JENKINS_ADMIN_ID=admin
      - JENKINS_ADMIN_PASSWORD=jenkins2024
    user: root
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080/login || exit 1"]
      interval: 60s
      timeout: 5s
      retries: 5

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
      - "--path.procfs=/host/proc"
      - "--path.rootfs=/rootfs"
      - "--path.sysfs=/host/sys"
      - "--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)"

  # Redis
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
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/health || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3'
    
    Set-Content -Path "$InstallPath\docker-compose.yml" -Value $dockerComposeContent
    Write-Success "Docker Compose configuration created"
}

# ==============================================
# CONFIGURATION FILES CREATION
# ==============================================

function New-ConfigurationFiles {
    Write-Info "Creating configuration files..."
    
    # Prometheus Configuration - Use single quotes
    $prometheusConfig = 'global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: "gitops-monitor"
    environment: "development"

alerting:
  alertmanagers:
    - static_configs:
        - targets: ["alertmanager:9093"]

rule_files:
  - "/etc/prometheus/rules/*.yml"

scrape_configs:
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]
    
  - job_name: "node-exporter"
    static_configs:
      - targets: ["node-exporter:9100"]
  
  - job_name: "grafana"
    static_configs:
      - targets: ["grafana:3000"]
  
  - job_name: "jenkins"
    metrics_path: "/prometheus"
    static_configs:
      - targets: ["jenkins:8080"]
  
  - job_name: "app"
    static_configs:
      - targets: ["app:3000"]'
      
    Set-Content -Path "$InstallPath\config\prometheus\prometheus.yml" -Value $prometheusConfig
    
    # Alert Rules - Use single quotes
    $alertRules = 'groups:
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
          description: "{{ $labels.instance }} of job {{ $labels.job }} has been down for more than 1 minute."'
          
    Set-Content -Path "$InstallPath\config\prometheus\rules\alerts.yml" -Value $alertRules
    
    # Grafana Datasource - Use single quotes
    $grafanaDatasource = 'apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "15s"'
      
    Set-Content -Path "$InstallPath\config\grafana\provisioning\datasources\prometheus.yml" -Value $grafanaDatasource
    
    # Grafana Dashboard Provider - Use single quotes
    $dashboardProvider = 'apiVersion: 1

providers:
  - name: "GitOps Dashboards"
    orgId: 1
    folder: ""
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards'
      
    Set-Content -Path "$InstallPath\config\grafana\provisioning\dashboards\provider.yml" -Value $dashboardProvider
    
    # AlertManager Configuration - Use single quotes
    $alertmanagerConfig = 'global:
  resolve_timeout: 5m

route:
  group_by: ["alertname", "cluster", "service"]
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: "default"
  
receivers:
  - name: "default"'
  
    Set-Content -Path "$InstallPath\config\alertmanager\alertmanager.yml" -Value $alertmanagerConfig
    
    # Redis Configuration
    $redisConfig = '# Redis configuration for GitOps TP
bind 0.0.0.0
protected-mode no
port 6379
tcp-backlog 511
timeout 0
tcp-keepalive 300
databases 16
save 900 1
save 300 10
save 60 10000
maxmemory 256mb
maxmemory-policy allkeys-lru'

    Set-Content -Path "$InstallPath\config\redis\redis.conf" -Value $redisConfig
    
    # Jenkins Init Script
    $jenkinsInit = 'import jenkins.model.*
import hudson.security.*

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
instance.save()'

    Set-Content -Path "$InstallPath\config\jenkins\init.groovy.d\01-admin-user.groovy" -Value $jenkinsInit
    
    Write-Success "Configuration files created"
}

# ==============================================
# APPLICATION FILES CREATION
# ==============================================

function New-ApplicationFiles {
    Write-Info "Creating sample application..."
    
    # Dockerfile
    $dockerfile = 'FROM node:18-alpine

WORKDIR /app

COPY package*.json ./
RUN npm ci --only=production

COPY . .

EXPOSE 3000

USER node

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD node -e "require(''http'').get(''http://localhost:3000/health'', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

CMD ["node", "server.js"]'

    Set-Content -Path "$InstallPath\application\Dockerfile" -Value $dockerfile
    
    # package.json
    $packageJson = '{
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
}'

    Set-Content -Path "$InstallPath\application\package.json" -Value $packageJson
    
    # server.js - Create as a text file to avoid PowerShell interpretation
    $serverJsPath = "$InstallPath\application\server.js"
    
    # Write the file line by line to avoid interpretation issues
    $serverJsLines = @(
        "const express = require('express');"
        "const client = require('prom-client');"
        "const redis = require('redis');"
        ""
        "const app = express();"
        "const register = new client.Registry();"
        ""
        "// Add default metrics"
        "client.collectDefaultMetrics({ register });"
        ""
        "// Custom metrics"
        "const httpRequestDuration = new client.Histogram({"
        "    name: 'http_request_duration_ms',"
        "    help: 'Duration of HTTP requests in ms',"
        "    labelNames: ['method', 'route', 'status_code'],"
        "    buckets: [0.1, 5, 15, 50, 100, 500]"
        "});"
        "register.registerMetric(httpRequestDuration);"
        ""
        "const httpRequestTotal = new client.Counter({"
        "    name: 'http_requests_total',"
        "    help: 'Total number of HTTP requests',"
        "    labelNames: ['method', 'route', 'status_code']"
        "});"
        "register.registerMetric(httpRequestTotal);"
        ""
        "// Redis connection"
        "let redisClient;"
        "async function connectRedis() {"
        "    try {"
        "        redisClient = redis.createClient({"
        "            socket: { host: process.env.REDIS_HOST || 'redis', port: 6379 }"
        "        });"
        "        await redisClient.connect();"
        "        console.log('Connected to Redis');"
        "    } catch (err) {"
        "        console.error('Redis connection failed:', err);"
        "    }"
        "}"
        "connectRedis();"
        ""
        "// Middleware to track metrics"
        "app.use((req, res, next) => {"
        "    const start = Date.now();"
        "    res.on('finish', () => {"
        "        const duration = Date.now() - start;"
        "        httpRequestDuration.observe("
        "            { method: req.method, route: req.path, status_code: res.statusCode },"
        "            duration"
        "        );"
        "        httpRequestTotal.inc({ method: req.method, route: req.path, status_code: res.statusCode });"
        "    });"
        "    next();"
        "});"
        ""
        "// Routes"
        "app.get('/', (req, res) => {"
        "    res.json({ message: 'GitOps Monitoring App', version: '1.0.0' });"
        "});"
        ""
        "app.get('/health', (req, res) => {"
        "    res.status(200).json({ status: 'healthy', timestamp: new Date().toISOString() });"
        "});"
        ""
        "app.get('/metrics', async (req, res) => {"
        "    res.set('Content-Type', register.contentType);"
        "    res.end(await register.metrics());"
        "});"
        ""
        "app.get('/api/info', async (req, res) => {"
        "    const info = {"
        "        app: 'GitOps Monitoring',"
        "        version: '1.0.0',"
        "        environment: process.env.NODE_ENV || 'development',"
        "        uptime: process.uptime(),"
        "        redis: redisClient && redisClient.isOpen ? 'connected' : 'disconnected'"
        "    };"
        "    res.json(info);"
        "});"
        ""
        "const PORT = process.env.PORT || 3000;"
        "app.listen(PORT, () => {"
        "    console.log(`Server running on port `${PORT}`);"
        "});"
    )
    
    $serverJsLines | Out-File -FilePath $serverJsPath -Encoding UTF8
    
    Write-Success "Application files created"
}

# ==============================================
# JENKINSFILE CREATION
# ==============================================

function New-Jenkinsfile {
    Write-Info "Creating Jenkinsfile..."
    
    $jenkinsfileContent = 'pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = "docker.io"
        IMAGE_NAME = "gitops-app"
        IMAGE_TAG = "${BUILD_NUMBER}"
    }
    
    stages {
        stage("Checkout") {
            steps {
                checkout scm
            }
        }
        
        stage("Build") {
            steps {
                script {
                    docker.build("${IMAGE_NAME}:${IMAGE_TAG}", "./application")
                }
            }
        }
        
        stage("Test") {
            steps {
                script {
                    sh "docker run ${IMAGE_NAME}:${IMAGE_TAG} npm test"
                }
            }
        }
        
        stage("Deploy") {
            steps {
                script {
                    sh "docker-compose up -d app"
                }
            }
        }
    }
    
    post {
        success {
            echo "[OK] Pipeline completed successfully!"
        }
        failure {
            echo "[ERROR] Pipeline failed!"
        }
    }
}'
    
    Set-Content -Path "$InstallPath\Jenkinsfile" -Value $jenkinsfileContent
    Write-Success "Jenkinsfile created"
}

# ==============================================
# README CREATION
# ==============================================

function New-README {
    Write-Info "Creating README..."
    
    $readmePath = "$InstallPath\README.md"
    
    # Create README line by line
    $readmeLines = @(
        "# GitOps TP - Monitoring Stack"
        ""
        "## Services Included"
        ""
        "- Prometheus (9090): Time-series metrics database"
        "- Grafana (3000): Visualization and dashboards"
        "- Jenkins (8081): CI/CD automation server"
        "- AlertManager (9093): Alert management"
        "- Node Exporter (9100): System metrics"
        "- Redis (6379): Cache and queue"
        "- Application (3001): Sample monitoring app"
        ""
        "## Quick Start"
        ""
        "```powershell"
        "# Start all services"
        "docker-compose up -d"
        ""
        "# Check status"
        "docker-compose ps"
        ""
        "# View logs"
        "docker-compose logs -f [service-name]"
        "```"
        ""
        "## Default Credentials"
        ""
        "| Service | Username | Password |"
        "|---------|----------|----------|"
        "| Grafana | admin | gitops2024 |"
        "| Jenkins | admin | jenkins2024 |"
        ""
        "## Configuration"
        ""
        "All configuration files are in the config/ directory:"
        "- prometheus/: Prometheus configuration and rules"
        "- grafana/: Grafana provisioning"
        "- jenkins/: Jenkins initialization scripts"
        "- alertmanager/: Alert routing configuration"
        ""
        "## Testing"
        ""
        "Run the grading script:"
        "```powershell"
        ".\Grade-GitOpsTP.ps1"
        "```"
        ""
        "## Stopping Services"
        ""
        "```powershell"
        "# Stop all services"
        "docker-compose down"
        ""
        "# Stop and remove volumes"
        "docker-compose down -v"
        "```"
    )
    
    $readmeLines | Out-File -FilePath $readmePath -Encoding UTF8
    
    Write-Success "README created"
}

# ==============================================
# SERVICES STARTUP
# ==============================================

function Start-GitOpsStack {
    Write-Info "Starting GitOps stack..."
    
    Set-Location $InstallPath
    
    # Pull images
    Write-Info "Pulling Docker images (this may take a while)..."
    docker-compose pull 2>&1 | Out-String
    
    # Start services
    Write-Info "Starting services..."
    docker-compose up -d 2>&1 | Out-String
    
    # Wait for services
    Write-Info "Waiting for services to be healthy..."
    Start-Sleep -Seconds 10
    
    Write-Success "GitOps stack started"
}

# ==============================================
# ACCESS INFORMATION DISPLAY
# ==============================================

function Show-AccessInfo {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host "                    [OK] Installation Complete!                 " -ForegroundColor Green
    Write-Host "================================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Project Location: $InstallPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Services Access URLs:" -ForegroundColor Cyan
    Write-Host "  - Prometheus:    http://localhost:9090" -ForegroundColor White
    Write-Host "  - Grafana:       http://localhost:3000  (admin / gitops2024)" -ForegroundColor White
    Write-Host "  - Jenkins:       http://localhost:8081  (admin / jenkins2024)" -ForegroundColor White
    Write-Host "  - AlertManager:  http://localhost:9093" -ForegroundColor White
    Write-Host "  - Node Exporter: http://localhost:9100/metrics" -ForegroundColor White
    Write-Host "  - Application:   http://localhost:3001" -ForegroundColor White
    Write-Host ""
    Write-Host "Useful Commands:" -ForegroundColor Cyan
    Write-Host "  - Check status:  docker-compose ps" -ForegroundColor White
    Write-Host "  - View logs:     docker-compose logs -f [service]" -ForegroundColor White
    Write-Host "  - Stop stack:    docker-compose down" -ForegroundColor White
    Write-Host "  - Restart:       docker-compose restart" -ForegroundColor White
    Write-Host "  - Run tests:     .\Grade-GitOpsTP.ps1" -ForegroundColor White
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
    
    # Copy grading script if exists
    if (Test-Path "$PSScriptRoot\Grade-GitOpsTP.ps1") {
        Copy-Item -Path "$PSScriptRoot\Grade-GitOpsTP.ps1" -Destination "$InstallPath\Grade-GitOpsTP.ps1" -Force
        Write-Success "Grading script copied"
    }
    
    # Create uninstall script
    $uninstallScript = 'Write-Host "Stopping and removing GitOps TP..." -ForegroundColor Yellow
docker-compose -f "C:\GitOpsTP\docker-compose.yml" down -v
docker system prune -af
Remove-Item -Path "C:\GitOpsTP" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "GitOps TP uninstalled successfully" -ForegroundColor Green'
    
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
