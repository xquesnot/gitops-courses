# ============================================
# GitOps TP - Ultra Simple Installation Script
# File: Install-GitOpsTP-Simple.ps1
# Version: 6.0 - Simplified
# Author: DevOps Master Course
# ============================================

#Requires -RunAsAdministrator

param(
    [string]$InstallPath = "C:\GitOpsTP",
    [switch]$AutoStart = $false
)

$ErrorActionPreference = "Stop"

# Simple banner
Write-Host ""
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "           GitOps TP - Installation Script v6.0                 " -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan
Write-Host ""

# Check Docker
Write-Host "[INFO] Checking Docker..." -ForegroundColor Cyan
try {
    docker --version | Out-Null
    Write-Host "[OK] Docker is installed" -ForegroundColor Green
}
catch {
    Write-Host "[ERROR] Docker is not installed or not running" -ForegroundColor Red
    Write-Host "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop/" -ForegroundColor Yellow
    exit 1
}

# Check Docker Compose
Write-Host "[INFO] Checking Docker Compose..." -ForegroundColor Cyan
try {
    docker-compose --version | Out-Null
    Write-Host "[OK] Docker Compose is installed" -ForegroundColor Green
}
catch {
    try {
        docker compose version | Out-Null
        Write-Host "[OK] Docker Compose (plugin) is installed" -ForegroundColor Green
    }
    catch {
        Write-Host "[ERROR] Docker Compose is not installed" -ForegroundColor Red
        exit 1
    }
}

# Create directories
Write-Host "[INFO] Creating project structure..." -ForegroundColor Cyan

$dirs = @(
    "$InstallPath",
    "$InstallPath\config",
    "$InstallPath\config\prometheus",
    "$InstallPath\config\prometheus\rules",
    "$InstallPath\config\grafana",
    "$InstallPath\config\grafana\provisioning",
    "$InstallPath\config\grafana\provisioning\datasources",
    "$InstallPath\config\grafana\provisioning\dashboards",
    "$InstallPath\config\alertmanager",
    "$InstallPath\config\jenkins",
    "$InstallPath\config\jenkins\init.groovy.d",
    "$InstallPath\config\redis",
    "$InstallPath\application"
)

foreach ($dir in $dirs) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

Write-Host "[OK] Project structure created" -ForegroundColor Green

# Create docker-compose.yml
Write-Host "[INFO] Creating docker-compose.yml..." -ForegroundColor Cyan

@'
version: "3.9"

networks:
  gitops-network:
    driver: bridge

volumes:
  prometheus_data:
  grafana_data:
  jenkins_data:

services:
  prometheus:
    image: prom/prometheus:latest
    container_name: gitops-prometheus
    restart: unless-stopped
    networks:
      - gitops-network
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus:/etc/prometheus:ro
      - prometheus_data:/prometheus
    command:
      - "--config.file=/etc/prometheus/prometheus.yml"
      - "--storage.tsdb.path=/prometheus"

  grafana:
    image: grafana/grafana:latest
    container_name: gitops-grafana
    restart: unless-stopped
    networks:
      - gitops-network
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

  alertmanager:
    image: prom/alertmanager:latest
    container_name: gitops-alertmanager
    restart: unless-stopped
    networks:
      - gitops-network
    ports:
      - "9093:9093"
    volumes:
      - ./config/alertmanager:/etc/alertmanager:ro
    command:
      - "--config.file=/etc/alertmanager/alertmanager.yml"

  jenkins:
    image: jenkins/jenkins:lts
    container_name: gitops-jenkins
    restart: unless-stopped
    networks:
      - gitops-network
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

  node-exporter:
    image: prom/node-exporter:latest
    container_name: gitops-node-exporter
    restart: unless-stopped
    networks:
      - gitops-network
    ports:
      - "9100:9100"
    command:
      - "--path.procfs=/host/proc"
      - "--path.rootfs=/rootfs"
      - "--path.sysfs=/host/sys"

  redis:
    image: redis:alpine
    container_name: gitops-redis
    restart: unless-stopped
    networks:
      - gitops-network
    ports:
      - "6379:6379"

  app:
    build:
      context: ./application
      dockerfile: Dockerfile
    container_name: gitops-app
    restart: unless-stopped
    networks:
      - gitops-network
    ports:
      - "3001:3000"
    environment:
      - NODE_ENV=production
      - REDIS_HOST=redis
    depends_on:
      - redis
'@ | Out-File -FilePath "$InstallPath\docker-compose.yml" -Encoding UTF8

Write-Host "[OK] docker-compose.yml created" -ForegroundColor Green

# Create Prometheus config
Write-Host "[INFO] Creating Prometheus configuration..." -ForegroundColor Cyan

@'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

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
    static_configs:
      - targets: ["jenkins:8080"]
  
  - job_name: "app"
    static_configs:
      - targets: ["app:3000"]
'@ | Out-File -FilePath "$InstallPath\config\prometheus\prometheus.yml" -Encoding UTF8

Write-Host "[OK] Prometheus configuration created" -ForegroundColor Green

# Create Alert rules
Write-Host "[INFO] Creating alert rules..." -ForegroundColor Cyan

@'
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
          summary: "Instance down"
          description: "Instance has been down for more than 1 minute."
'@ | Out-File -FilePath "$InstallPath\config\prometheus\rules\alerts.yml" -Encoding UTF8

Write-Host "[OK] Alert rules created" -ForegroundColor Green

# Create Grafana datasource
Write-Host "[INFO] Creating Grafana datasource..." -ForegroundColor Cyan

@'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
'@ | Out-File -FilePath "$InstallPath\config\grafana\provisioning\datasources\prometheus.yml" -Encoding UTF8

Write-Host "[OK] Grafana datasource created" -ForegroundColor Green

# Create Grafana dashboard provider
Write-Host "[INFO] Creating Grafana dashboard provider..." -ForegroundColor Cyan

@'
apiVersion: 1

providers:
  - name: "GitOps Dashboards"
    orgId: 1
    folder: ""
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
'@ | Out-File -FilePath "$InstallPath\config\grafana\provisioning\dashboards\provider.yml" -Encoding UTF8

Write-Host "[OK] Grafana dashboard provider created" -ForegroundColor Green

# Create AlertManager config
Write-Host "[INFO] Creating AlertManager configuration..." -ForegroundColor Cyan

@'
global:
  resolve_timeout: 5m

route:
  group_by: ["alertname"]
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: "default"

receivers:
  - name: "default"
'@ | Out-File -FilePath "$InstallPath\config\alertmanager\alertmanager.yml" -Encoding UTF8

Write-Host "[OK] AlertManager configuration created" -ForegroundColor Green

# Create Redis config
Write-Host "[INFO] Creating Redis configuration..." -ForegroundColor Cyan

@'
bind 0.0.0.0
protected-mode no
port 6379
timeout 0
tcp-keepalive 300
databases 16
save 900 1
save 300 10
save 60 10000
maxmemory 256mb
maxmemory-policy allkeys-lru
'@ | Out-File -FilePath "$InstallPath\config\redis\redis.conf" -Encoding UTF8

Write-Host "[OK] Redis configuration created" -ForegroundColor Green

# Create Jenkins init script
Write-Host "[INFO] Creating Jenkins init script..." -ForegroundColor Cyan

@'
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()

instance.setInstallState(InstallState.INITIAL_SETUP_COMPLETED)

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("admin", "jenkins2024")
instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

instance.save()
'@ | Out-File -FilePath "$InstallPath\config\jenkins\init.groovy.d\01-admin-user.groovy" -Encoding UTF8

Write-Host "[OK] Jenkins init script created" -ForegroundColor Green

# Create Application Dockerfile
Write-Host "[INFO] Creating application Dockerfile..." -ForegroundColor Cyan

@'
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]
'@ | Out-File -FilePath "$InstallPath\application\Dockerfile" -Encoding UTF8

Write-Host "[OK] Dockerfile created" -ForegroundColor Green

# Create package.json
Write-Host "[INFO] Creating package.json..." -ForegroundColor Cyan

@'
{
  "name": "gitops-app",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2",
    "prom-client": "^14.2.0",
    "redis": "^4.6.10"
  }
}
'@ | Out-File -FilePath "$InstallPath\application\package.json" -Encoding UTF8

Write-Host "[OK] package.json created" -ForegroundColor Green

# Create server.js
Write-Host "[INFO] Creating server.js..." -ForegroundColor Cyan

@'
const express = require("express");
const client = require("prom-client");
const app = express();
const register = new client.Registry();

client.collectDefaultMetrics({ register });

const httpRequests = new client.Counter({
  name: "http_requests_total",
  help: "Total HTTP requests",
  labelNames: ["method", "route", "status"],
  registers: [register]
});

app.use((req, res, next) => {
  res.on("finish", () => {
    httpRequests.inc({
      method: req.method,
      route: req.path,
      status: res.statusCode
    });
  });
  next();
});

app.get("/", (req, res) => {
  res.json({ message: "GitOps App", version: "1.0.0" });
});

app.get("/health", (req, res) => {
  res.json({ status: "healthy" });
});

app.get("/metrics", async (req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
'@ | Out-File -FilePath "$InstallPath\application\server.js" -Encoding UTF8

Write-Host "[OK] server.js created" -ForegroundColor Green

# Create README
Write-Host "[INFO] Creating README..." -ForegroundColor Cyan

$readme = @"
# GitOps TP - Monitoring Stack

## Services

- Prometheus: http://localhost:9090
- Grafana: http://localhost:3000 (admin/gitops2024)
- Jenkins: http://localhost:8081 (admin/jenkins2024)
- AlertManager: http://localhost:9093
- Application: http://localhost:3001

## Commands

Start services:
docker-compose up -d

Check status:
docker-compose ps

View logs:
docker-compose logs -f

Stop services:
docker-compose down

Stop and remove volumes:
docker-compose down -v
"@

$readme | Out-File -FilePath "$InstallPath\README.md" -Encoding UTF8

Write-Host "[OK] README created" -ForegroundColor Green

# Copy grading script if exists
if (Test-Path "$PSScriptRoot\Grade-GitOpsTP.ps1") {
    Copy-Item -Path "$PSScriptRoot\Grade-GitOpsTP.ps1" -Destination "$InstallPath\Grade-GitOpsTP.ps1" -Force
    Write-Host "[OK] Grading script copied" -ForegroundColor Green
}

# Start services if requested
if ($AutoStart) {
    Write-Host "[INFO] Starting services..." -ForegroundColor Cyan
    Set-Location $InstallPath
    docker-compose pull
    docker-compose up -d
    Write-Host "[OK] Services started" -ForegroundColor Green
}

# Display final information
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "              Installation Complete!                            " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Project Location: $InstallPath" -ForegroundColor Yellow
Write-Host ""
Write-Host "Services URLs:" -ForegroundColor Cyan
Write-Host "  Prometheus:  http://localhost:9090" -ForegroundColor White
Write-Host "  Grafana:     http://localhost:3000 (admin/gitops2024)" -ForegroundColor White
Write-Host "  Jenkins:     http://localhost:8081 (admin/jenkins2024)" -ForegroundColor White
Write-Host "  AlertManager: http://localhost:9093" -ForegroundColor White
Write-Host "  Application: http://localhost:3001" -ForegroundColor White
Write-Host ""
Write-Host "To start services:" -ForegroundColor Cyan
Write-Host "  cd $InstallPath" -ForegroundColor White
Write-Host "  docker-compose up -d" -ForegroundColor White
Write-Host ""
Write-Host "[OK] Setup complete!" -ForegroundColor Green
