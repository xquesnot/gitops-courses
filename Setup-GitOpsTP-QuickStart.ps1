# ============================================
# GitOps TP - Quick Setup All-in-One Script
# File: Setup-GitOpsTP-QuickStart.ps1
# Version: 1.0.0
# Single file to rule them all!
# ============================================

#Requires -RunAsAdministrator

param(
    [switch]$InstallOnly = $false,
    [switch]$TestOnly = $false,
    [switch]$GradeOnly = $false
)

# Embedded Docker Compose Configuration
$DockerComposeContent = @'
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
  prometheus:
    image: prom/prometheus:latest
    container_name: gitops-prometheus
    restart: unless-stopped
    networks:
      - gitops-network
    ports:
      - "9090:9090"
    volumes:
      - prometheus_data:/prometheus
      - ./config/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost:9090/-/healthy"]
      interval: 30s
      timeout: 5s
      retries: 3

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
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:3000/api/health || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3

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
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - JENKINS_OPTS=--prefix=/
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
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro

  app:
    image: nginx:alpine
    container_name: gitops-app
    restart: unless-stopped
    networks:
      - gitops-network
    ports:
      - "3001:80"
    healthcheck:
      test: ["CMD", "wget", "--spider", "-q", "http://localhost"]
      interval: 30s
      timeout: 5s
      retries: 3
'@

# Prometheus Configuration
$PrometheusConfig = @'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

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
  
  - job_name: 'app'
    static_configs:
      - targets: ['app:80']
'@

# Grafana Datasource Configuration
$GrafanaDatasource = @'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
'@

# Quick Grade Function
function Quick-Grade {
    Write-Host "🎓 Running Quick Grading..." -ForegroundColor Cyan
    
    $score = 0
    $maxScore = 100
    
    # Check Docker
    if (docker version 2>$null) {
        $score += 10
        Write-Host "✅ Docker installed (+10)" -ForegroundColor Green
    }
    
    # Check Containers
    $containers = docker ps --format "{{.Names}}" 2>$null
    $requiredContainers = @("gitops-prometheus", "gitops-grafana", "gitops-jenkins", "gitops-app")
    foreach ($container in $requiredContainers) {
        if ($containers -contains $container) {
            $score += 10
            Write-Host "✅ $container running (+10)" -ForegroundColor Green
        }
        else {
            Write-Host "❌ $container not found" -ForegroundColor Red
        }
    }
    
    # Check Services
    $services = @(
        @{Name="Prometheus"; URL="http://localhost:9090/-/healthy"; Points=15},
        @{Name="Grafana"; URL="http://localhost:3000/api/health"; Points=15},
        @{Name="Application"; URL="http://localhost:3001"; Points=10}
    )
    
    foreach ($service in $services) {
        try {
            $response = Invoke-WebRequest -Uri $service.URL -TimeoutSec 3 -UseBasicParsing 2>$null
            if ($response.StatusCode -eq 200 -or $response.StatusCode -eq 302) {
                $score += $service.Points
                Write-Host "✅ $($service.Name) accessible (+$($service.Points))" -ForegroundColor Green
            }
        }
        catch {
            Write-Host "❌ $($service.Name) not accessible" -ForegroundColor Red
        }
    }
    
    # Check Configuration Files
    if (Test-Path "C:\GitOpsTP\config\prometheus\prometheus.yml") {
        $score += 10
        Write-Host "✅ Prometheus config exists (+10)" -ForegroundColor Green
    }
    
    if (Test-Path "C:\GitOpsTP\docker-compose.yml") {
        $score += 10
        Write-Host "✅ Docker Compose file exists (+10)" -ForegroundColor Green
    }
    
    # Calculate Grade
    $percentage = [Math]::Round(($score / $maxScore) * 100, 1)
    $grade = [Math]::Round(($score / $maxScore) * 20, 2)
    
    Write-Host ""
    Write-Host "════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Score: $score / $maxScore" -ForegroundColor Yellow
    Write-Host "Percentage: $percentage%" -ForegroundColor Yellow
    Write-Host "Grade: $grade / 20" -ForegroundColor $(if($grade -ge 14){"Green"}elseif($grade -ge 10){"Yellow"}else{"Red"})
    Write-Host "════════════════════════════════" -ForegroundColor Cyan
}

# Main Setup Function
function Setup-GitOps {
    $installPath = "C:\GitOpsTP"
    
    Write-Host @"
╔══════════════════════════════════════╗
║   GitOps TP - Quick Start Setup      ║
║          All-in-One Script           ║
╚══════════════════════════════════════╝
"@ -ForegroundColor Cyan
    
    # Create directories
    Write-Host "📁 Creating project structure..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $installPath -Force | Out-Null
    New-Item -ItemType Directory -Path "$installPath\config\prometheus" -Force | Out-Null
    New-Item -ItemType Directory -Path "$installPath\config\grafana\provisioning\datasources" -Force | Out-Null
    
    # Write configuration files
    Write-Host "📝 Writing configuration files..." -ForegroundColor Yellow
    $DockerComposeContent | Out-File -FilePath "$installPath\docker-compose.yml" -Encoding UTF8
    $PrometheusConfig | Out-File -FilePath "$installPath\config\prometheus\prometheus.yml" -Encoding UTF8
    $GrafanaDatasource | Out-File -FilePath "$installPath\config\grafana\provisioning\datasources\prometheus.yml" -Encoding UTF8
    
    # Start Docker Stack
    Write-Host "🚀 Starting Docker stack..." -ForegroundColor Yellow
    Set-Location $installPath
    docker-compose pull 2>&1 | Out-String | Out-Null
    docker-compose up -d 2>&1 | Out-String | Out-Null
    
    # Wait for services
    Write-Host "⏳ Waiting for services to start..." -ForegroundColor Yellow
    Start-Sleep -Seconds 15
    
    # Display URLs
    Write-Host ""
    Write-Host "✅ Installation Complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📌 Access URLs:" -ForegroundColor Cyan
    Write-Host "  Prometheus:  http://localhost:9090" -ForegroundColor White
    Write-Host "  Grafana:     http://localhost:3000 (admin/gitops2024)" -ForegroundColor White
    Write-Host "  Jenkins:     http://localhost:8081" -ForegroundColor White
    Write-Host "  Application: http://localhost:3001" -ForegroundColor White
}

# Check Docker Function
function Test-DockerInstalled {
    try {
        docker version 2>&1 | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

# Main Execution
try {
    if ($TestOnly) {
        if (-not (Test-DockerInstalled)) {
            Write-Host "❌ Docker is not installed!" -ForegroundColor Red
            exit 1
        }
        # Run quick tests
        Write-Host "Running tests..." -ForegroundColor Cyan
        docker ps
        exit 0
    }
    
    if ($GradeOnly) {
        Quick-Grade
        exit 0
    }
    
    # Check Docker
    if (-not (Test-DockerInstalled)) {
        Write-Host "❌ Docker is not installed!" -ForegroundColor Red
        Write-Host "Please install Docker Desktop from: https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
        
        $response = Read-Host "Would you like to open the download page? (Y/N)"
        if ($response -eq 'Y') {
            Start-Process "https://www.docker.com/products/docker-desktop"
        }
        exit 1
    }
    
    # Run Setup
    Setup-GitOps
    
    # Run Quick Grade
    Write-Host ""
    Write-Host "Running automatic grading..." -ForegroundColor Cyan
    Start-Sleep -Seconds 5
    Quick-Grade
    
    # Offer to open browser
    Write-Host ""
    $response = Read-Host "Would you like to open Grafana in your browser? (Y/N)"
    if ($response -eq 'Y') {
        Start-Process "http://localhost:3000"
    }
}
catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}
