# ============================================
# GitOps TP - Automatic Grading Script
# File: Grade-GitOpsTP.ps1
# Version: 1.0.0
# Author: DevOps Master Course
# ============================================

param(
    [string]$ProjectPath = "C:\GitOpsTP",
    [string]$StudentName = "",
    [string]$StudentID = "",
    [switch]$GenerateReport = $true,
    [switch]$Verbose = $false
)

# Configuration
$ErrorActionPreference = "SilentlyContinue"
$script:TotalPoints = 0
$script:MaxPoints = 100
$script:TestResults = @()
$script:DetailedFeedback = @()

# Grade Categories
$GradeCategories = @{
    "Infrastructure" = 20
    "Configuration" = 15
    "Security" = 20
    "CICD" = 20
    "Monitoring" = 15
    "Documentation" = 5
    "BestPractices" = 5
}

# Color functions
function Write-TestResult {
    param(
        [string]$TestName,
        [int]$Points,
        [int]$MaxPoints,
        [bool]$Passed,
        [string]$Details = ""
    )
    
    $status = if ($Passed) { "✅ PASS" } else { "❌ FAIL" }
    $color = if ($Passed) { "Green" } else { "Red" }
    
    Write-Host "$status | " -NoNewline -ForegroundColor $color
    Write-Host "$TestName " -NoNewline
    Write-Host "[$Points/$MaxPoints points]" -ForegroundColor Yellow
    
    if ($Details -and $Verbose) {
        Write-Host "  └─ $Details" -ForegroundColor Gray
    }
    
    $script:TestResults += [PSCustomObject]@{
        TestName = $TestName
        Category = $currentCategory
        Points = $Points
        MaxPoints = $MaxPoints
        Passed = $Passed
        Details = $Details
        Timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    }
    
    $script:TotalPoints += $Points
}

# Test Functions
function Test-DockerEnvironment {
    $currentCategory = "Infrastructure"
    Write-Host "`n🔧 Testing Docker Environment..." -ForegroundColor Cyan
    
    # Check if Docker is running
    $dockerRunning = $null -ne (docker version 2>$null)
    Write-TestResult -TestName "Docker daemon running" -Points $(if($dockerRunning){2}else{0}) -MaxPoints 2 -Passed $dockerRunning
    
    # Check Docker Compose
    $composeInstalled = $null -ne (docker-compose version 2>$null)
    Write-TestResult -TestName "Docker Compose installed" -Points $(if($composeInstalled){2}else{0}) -MaxPoints 2 -Passed $composeInstalled
    
    # Check for docker-compose.yml
    $composeFile = Test-Path "$ProjectPath\docker-compose.yml"
    Write-TestResult -TestName "docker-compose.yml exists" -Points $(if($composeFile){3}else{0}) -MaxPoints 3 -Passed $composeFile
    
    if ($composeFile) {
        # Validate docker-compose.yml syntax
        Set-Location $ProjectPath
        $validation = docker-compose config -q 2>&1
        $valid = $LASTEXITCODE -eq 0
        Write-TestResult -TestName "docker-compose.yml valid syntax" -Points $(if($valid){3}else{0}) -MaxPoints 3 -Passed $valid
    }
}

function Test-RunningContainers {
    $currentCategory = "Infrastructure"
    Write-Host "`n🐳 Testing Running Containers..." -ForegroundColor Cyan
    
    $requiredContainers = @(
        @{Name="prometheus"; Points=2},
        @{Name="grafana"; Points=2},
        @{Name="jenkins"; Points=2},
        @{Name="node-exporter"; Points=1},
        @{Name="cadvisor"; Points=1},
        @{Name="alertmanager"; Points=1},
        @{Name="app"; Points=1}
    )
    
    $runningContainers = docker ps --format "{{.Names}}" 2>$null
    
    foreach ($container in $requiredContainers) {
        $containerName = "gitops-$($container.Name)"
        $isRunning = $runningContainers -contains $containerName
        
        if ($isRunning) {
            # Check if container is healthy
            $health = docker inspect $containerName --format='{{.State.Health.Status}}' 2>$null
            $isHealthy = $health -eq "healthy" -or $health -eq $null
            $points = if($isHealthy) { $container.Points } else { [Math]::Floor($container.Points/2) }
            $details = if($isHealthy) { "Container healthy" } else { "Container unhealthy" }
        } else {
            $points = 0
            $details = "Container not found"
        }
        
        Write-TestResult -TestName "Container: $($container.Name)" -Points $points -MaxPoints $container.Points -Passed $isRunning -Details $details
    }
}

function Test-NetworkConfiguration {
    $currentCategory = "Infrastructure"
    Write-Host "`n🌐 Testing Network Configuration..." -ForegroundColor Cyan
    
    # Check if custom network exists
    $networks = docker network ls --format "{{.Name}}" 2>$null
    $networkExists = $networks -contains "gitopstp_gitops-network" -or $networks -contains "gitops-network"
    Write-TestResult -TestName "Custom network created" -Points $(if($networkExists){3}else{0}) -MaxPoints 3 -Passed $networkExists
    
    if ($networkExists) {
        # Check network configuration
        $networkName = if ($networks -contains "gitopstp_gitops-network") { "gitopstp_gitops-network" } else { "gitops-network" }
        $networkInfo = docker network inspect $networkName 2>$null | ConvertFrom-Json
        $hasCorrectSubnet = $networkInfo.IPAM.Config.Subnet -eq "172.20.0.0/16"
        Write-TestResult -TestName "Network subnet configuration" -Points $(if($hasCorrectSubnet){2}else{0}) -MaxPoints 2 -Passed $hasCorrectSubnet
    }
}

function Test-VolumeConfiguration {
    $currentCategory = "Infrastructure"
    Write-Host "`n💾 Testing Volume Configuration..." -ForegroundColor Cyan
    
    $requiredVolumes = @("prometheus_data", "grafana_data", "jenkins_data")
    $volumes = docker volume ls --format "{{.Name}}" 2>$null
    
    foreach ($volume in $requiredVolumes) {
        $volumeExists = $volumes -like "*$volume*"
        $points = if($volumeExists) { 1 } else { 0 }
        Write-TestResult -TestName "Volume: $volume" -Points $points -MaxPoints 1 -Passed ($volumeExists -ne $null)
    }
}

function Test-ServiceEndpoints {
    $currentCategory = "Monitoring"
    Write-Host "`n🌍 Testing Service Endpoints..." -ForegroundColor Cyan
    
    $endpoints = @(
        @{Name="Prometheus"; URL="http://localhost:9090/-/healthy"; Points=3},
        @{Name="Grafana"; URL="http://localhost:3000/api/health"; Points=3},
        @{Name="Jenkins"; URL="http://localhost:8081/login"; Points=3},
        @{Name="Application"; URL="http://localhost:3001/health"; Points=3},
        @{Name="Node Exporter"; URL="http://localhost:9100/metrics"; Points=1},
        @{Name="AlertManager"; URL="http://localhost:9093/-/healthy"; Points=2}
    )
    
    foreach ($endpoint in $endpoints) {
        try {
            $response = Invoke-WebRequest -Uri $endpoint.URL -TimeoutSec 5 -UseBasicParsing
            $accessible = $response.StatusCode -eq 200
            $points = if($accessible) { $endpoint.Points } else { 0 }
            $details = "HTTP $($response.StatusCode)"
        }
        catch {
            $accessible = $false
            $points = 0
            $details = "Connection failed"
        }
        
        Write-TestResult -TestName "$($endpoint.Name) endpoint" -Points $points -MaxPoints $endpoint.Points -Passed $accessible -Details $details
    }
}

function Test-PrometheusConfiguration {
    $currentCategory = "Configuration"
    Write-Host "`n📊 Testing Prometheus Configuration..." -ForegroundColor Cyan
    
    # Check configuration file
    $configExists = Test-Path "$ProjectPath\config\prometheus\prometheus.yml"
    Write-TestResult -TestName "Prometheus config file exists" -Points $(if($configExists){2}else{0}) -MaxPoints 2 -Passed $configExists
    
    # Check if Prometheus is scraping targets
    try {
        $targetsResponse = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/targets" -TimeoutSec 5
        $activeTargets = $targetsResponse.data.activeTargets
        $allTargetsUp = ($activeTargets | Where-Object { $_.health -ne "up" }).Count -eq 0
        $points = if($allTargetsUp) { 3 } elseif($activeTargets.Count -gt 0) { 2 } else { 0 }
        Write-TestResult -TestName "Prometheus targets configuration" -Points $points -MaxPoints 3 -Passed ($activeTargets.Count -gt 0) -Details "$($activeTargets.Count) active targets"
    }
    catch {
        Write-TestResult -TestName "Prometheus targets configuration" -Points 0 -MaxPoints 3 -Passed $false -Details "API not accessible"
    }
    
    # Check alert rules
    $alertRulesExist = Test-Path "$ProjectPath\config\prometheus\rules\*.yml"
    Write-TestResult -TestName "Alert rules configured" -Points $(if($alertRulesExist){2}else{0}) -MaxPoints 2 -Passed $alertRulesExist
}

function Test-GrafanaConfiguration {
    $currentCategory = "Configuration"
    Write-Host "`n📈 Testing Grafana Configuration..." -ForegroundColor Cyan
    
    # Check datasource configuration
    $datasourceConfig = Test-Path "$ProjectPath\config\grafana\provisioning\datasources\*.yml"
    Write-TestResult -TestName "Grafana datasource provisioning" -Points $(if($datasourceConfig){2}else{0}) -MaxPoints 2 -Passed $datasourceConfig
    
    # Check if datasource is working
    try {
        $headers = @{
            "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:gitops2024"))
        }
        $datasources = Invoke-RestMethod -Uri "http://localhost:3000/api/datasources" -Headers $headers -TimeoutSec 5
        $prometheusConfigured = ($datasources | Where-Object { $_.type -eq "prometheus" }).Count -gt 0
        Write-TestResult -TestName "Prometheus datasource active" -Points $(if($prometheusConfigured){3}else{0}) -MaxPoints 3 -Passed $prometheusConfigured
    }
    catch {
        Write-TestResult -TestName "Prometheus datasource active" -Points 0 -MaxPoints 3 -Passed $false -Details "API not accessible"
    }
    
    # Check dashboards
    $dashboardsExist = Test-Path "$ProjectPath\config\grafana\dashboards\*.json"
    Write-TestResult -TestName "Grafana dashboards configured" -Points $(if($dashboardsExist){3}else{0}) -MaxPoints 3 -Passed $dashboardsExist
}

function Test-SecurityScanning {
    $currentCategory = "Security"
    Write-Host "`n🔒 Testing Security Implementation..." -ForegroundColor Cyan
    
    # Check for Trivy installation/configuration
    $trivyInstalled = $null -ne (trivy --version 2>$null)
    Write-TestResult -TestName "Trivy scanner available" -Points $(if($trivyInstalled){3}else{0}) -MaxPoints 3 -Passed $trivyInstalled
    
    # Check for Checkov installation
    $checkovInstalled = $null -ne (checkov --version 2>$null)
    Write-TestResult -TestName "Checkov scanner available" -Points $(if($checkovInstalled){3}else{0}) -MaxPoints 3 -Passed $checkovInstalled
    
    # Check for security scan results
    $scanReports = Get-ChildItem -Path $ProjectPath -Filter "*security*.json" -Recurse 2>$null
    $hasReports = $scanReports.Count -gt 0
    Write-TestResult -TestName "Security scan reports generated" -Points $(if($hasReports){4}else{0}) -MaxPoints 4 -Passed $hasReports
    
    # Scan current images for vulnerabilities
    if ($trivyInstalled) {
        Write-Host "  Running security scan on current images..." -ForegroundColor Gray
        $images = @("gitops-prometheus", "gitops-grafana", "gitops-app")
        $criticalVulns = 0
        
        foreach ($image in $images) {
            $scanResult = trivy image --severity CRITICAL --format json --quiet "gitopstp_$image" 2>$null | ConvertFrom-Json
            if ($scanResult.Results) {
                $criticalVulns += ($scanResult.Results | ForEach-Object { $_.Vulnerabilities.Count } | Measure-Object -Sum).Sum
            }
        }
        
        $noCritical = $criticalVulns -eq 0
        Write-TestResult -TestName "No critical vulnerabilities" -Points $(if($noCritical){5}else{2}) -MaxPoints 5 -Passed $noCritical -Details "$criticalVulns critical vulnerabilities found"
    }
    
    # Check for secure practices in Dockerfiles
    if (Test-Path "$ProjectPath\application\Dockerfile") {
        $dockerfile = Get-Content "$ProjectPath\application\Dockerfile" -Raw
        $hasUser = $dockerfile -match "USER\s+\w+"
        $hasHealthcheck = $dockerfile -match "HEALTHCHECK"
        $points = 0
        $points += if($hasUser) { 2 } else { 0 }
        $points += if($hasHealthcheck) { 3 } else { 0 }
        Write-TestResult -TestName "Dockerfile security best practices" -Points $points -MaxPoints 5 -Passed ($points -eq 5) -Details "USER: $hasUser, HEALTHCHECK: $hasHealthcheck"
    }
}

function Test-JenkinsPipeline {
    $currentCategory = "CICD"
    Write-Host "`n🔄 Testing Jenkins CI/CD Pipeline..." -ForegroundColor Cyan
    
    # Check Jenkinsfile exists
    $jenkinsfileExists = Test-Path "$ProjectPath\Jenkinsfile"
    Write-TestResult -TestName "Jenkinsfile exists" -Points $(if($jenkinsfileExists){3}else{0}) -MaxPoints 3 -Passed $jenkinsfileExists
    
    if ($jenkinsfileExists) {
        $jenkinsfile = Get-Content "$ProjectPath\Jenkinsfile" -Raw
        
        # Check for required stages
        $stages = @{
            "Checkout" = 2
            "Security.*Scan" = 3
            "Build" = 2
            "Deploy.*Infrastructure" = 3
            "Configure.*Services" = 2
            "Test" = 3
        }
        
        foreach ($stage in $stages.GetEnumerator()) {
            $hasStage = $jenkinsfile -match "stage.*$($stage.Key)"
            Write-TestResult -TestName "Pipeline stage: $($stage.Key)" -Points $(if($hasStage){$stage.Value}else{0}) -MaxPoints $stage.Value -Passed $hasStage
        }
    }
    
    # Check Jenkins job configuration
    try {
        $jenkinsUrl = "http://localhost:8081"
        $response = Invoke-WebRequest -Uri "$jenkinsUrl/login" -TimeoutSec 5 -UseBasicParsing
        $jenkinsAccessible = $response.StatusCode -eq 200
        Write-TestResult -TestName "Jenkins accessible" -Points $(if($jenkinsAccessible){5}else{0}) -MaxPoints 5 -Passed $jenkinsAccessible
    }
    catch {
        Write-TestResult -TestName "Jenkins accessible" -Points 0 -MaxPoints 5 -Passed $false
    }
}

function Test-TerraformConfiguration {
    $currentCategory = "CICD"
    Write-Host "`n🏗️ Testing Terraform Configuration..." -ForegroundColor Cyan
    
    # Check for Terraform files
    $terraformDir = "$ProjectPath\terraform"
    $hasTerraformFiles = (Test-Path "$terraformDir\*.tf") -or (Test-Path "$ProjectPath\infrastructure\terraform\*.tf")
    Write-TestResult -TestName "Terraform files present" -Points $(if($hasTerraformFiles){3}else{0}) -MaxPoints 3 -Passed $hasTerraformFiles
    
    if ($hasTerraformFiles) {
        $tfDir = if (Test-Path "$terraformDir\*.tf") { $terraformDir } else { "$ProjectPath\infrastructure\terraform" }
        Set-Location $tfDir
        
        # Validate Terraform configuration
        $validation = terraform validate 2>&1
        $isValid = $LASTEXITCODE -eq 0
        Write-TestResult -TestName "Terraform configuration valid" -Points $(if($isValid){3}else{0}) -MaxPoints 3 -Passed $isValid
        
        # Check for proper structure
        $hasVariables = Test-Path "$tfDir\variables.tf"
        $hasOutputs = Test-Path "$tfDir\outputs.tf"
        $points = 0
        $points += if($hasVariables) { 1 } else { 0 }
        $points += if($hasOutputs) { 1 } else { 0 }
        Write-TestResult -TestName "Terraform structure" -Points $points -MaxPoints 2 -Passed ($points -eq 2) -Details "variables.tf: $hasVariables, outputs.tf: $hasOutputs"
    }
}

function Test-AnsibleConfiguration {
    $currentCategory = "CICD"
    Write-Host "`n🔧 Testing Ansible Configuration..." -ForegroundColor Cyan
    
    # Check for Ansible files
    $ansibleDir = "$ProjectPath\ansible"
    $hasAnsibleFiles = (Test-Path "$ansibleDir\*.yml") -or (Test-Path "$ProjectPath\configuration\ansible\*.yml")
    Write-TestResult -TestName "Ansible playbooks present" -Points $(if($hasAnsibleFiles){3}else{0}) -MaxPoints 3 -Passed $hasAnsibleFiles
    
    if ($hasAnsibleFiles) {
        $ansDir = if (Test-Path "$ansibleDir\*.yml") { $ansibleDir } else { "$ProjectPath\configuration\ansible" }
        
        # Check for inventory
        $hasInventory = Test-Path "$ansDir\inventory*"
        Write-TestResult -TestName "Ansible inventory configured" -Points $(if($hasInventory){2}else{0}) -MaxPoints 2 -Passed $hasInventory
        
        # Check playbook syntax
        $playbook = Get-ChildItem -Path $ansDir -Filter "*.yml" | Select-Object -First 1
        if ($playbook) {
            $syntaxCheck = ansible-playbook --syntax-check $playbook.FullName 2>&1
            $validSyntax = $LASTEXITCODE -eq 0
            Write-TestResult -TestName "Ansible playbook syntax" -Points $(if($validSyntax){3}else{0}) -MaxPoints 3 -Passed $validSyntax
        }
    }
}

function Test-Documentation {
    $currentCategory = "Documentation"
    Write-Host "`n📚 Testing Documentation..." -ForegroundColor Cyan
    
    # Check for README
    $hasReadme = Test-Path "$ProjectPath\README.md"
    Write-TestResult -TestName "README.md exists" -Points $(if($hasReadme){2}else{0}) -MaxPoints 2 -Passed $hasReadme
    
    if ($hasReadme) {
        $readme = Get-Content "$ProjectPath\README.md" -Raw
        $hasInstallation = $readme -match "install"
        $hasUsage = $readme -match "usage|run|start"
        $hasArchitecture = $readme -match "architecture|diagram|structure"
        $points = 0
        $points += if($hasInstallation) { 1 } else { 0 }
        $points += if($hasUsage) { 1 } else { 0 }
        $points += if($hasArchitecture) { 1 } else { 0 }
        Write-TestResult -TestName "README content quality" -Points $points -MaxPoints 3 -Passed ($points -eq 3) -Details "Install: $hasInstallation, Usage: $hasUsage, Arch: $hasArchitecture"
    }
}

function Test-BestPractices {
    $currentCategory = "BestPractices"
    Write-Host "`n⭐ Testing Best Practices..." -ForegroundColor Cyan
    
    # Check for .gitignore
    $hasGitignore = Test-Path "$ProjectPath\.gitignore"
    Write-TestResult -TestName ".gitignore configured" -Points $(if($hasGitignore){1}else{0}) -MaxPoints 1 -Passed $hasGitignore
    
    # Check for environment variables usage
    $envFiles = Get-ChildItem -Path $ProjectPath -Filter "*.env*" -Recurse 2>$null
    $usesEnvVars = $envFiles.Count -gt 0 -or (Test-Path "$ProjectPath\docker-compose.yml" -and (Get-Content "$ProjectPath\docker-compose.yml" -Raw) -match "environment:")
    Write-TestResult -TestName "Environment variables usage" -Points $(if($usesEnvVars){1}else{0}) -MaxPoints 1 -Passed $usesEnvVars
    
    # Check for logging configuration
    $containers = docker ps --format "{{.Names}}" 2>$null
    $loggingConfigured = $false
    foreach ($container in $containers) {
        if ($container -like "gitops-*") {
            $logs = docker logs $container --tail 10 2>$null
            if ($logs) {
                $loggingConfigured = $true
                break
            }
        }
    }
    Write-TestResult -TestName "Logging configured" -Points $(if($loggingConfigured){1}else{0}) -MaxPoints 1 -Passed $loggingConfigured
    
    # Check for resource limits in docker-compose
    if (Test-Path "$ProjectPath\docker-compose.yml") {
        $compose = Get-Content "$ProjectPath\docker-compose.yml" -Raw
        $hasResourceLimits = $compose -match "mem_limit|cpus:|resources:"
        Write-TestResult -TestName "Resource limits configured" -Points $(if($hasResourceLimits){1}else{0}) -MaxPoints 1 -Passed $hasResourceLimits
    }
    
    # Check for backup strategy
    $hasBackups = Test-Path "$ProjectPath\backups" -or Test-Path "$ProjectPath\scripts\backup*"
    Write-TestResult -TestName "Backup strategy implemented" -Points $(if($hasBackups){1}else{0}) -MaxPoints 1 -Passed $hasBackups
}

function Generate-Report {
    param([string]$OutputPath = "$ProjectPath\grading-report.html")
    
    $grade = [Math]::Round(($script:TotalPoints / $script:MaxPoints) * 20, 2)
    $percentage = [Math]::Round(($script:TotalPoints / $script:MaxPoints) * 100, 1)
    $letterGrade = switch ($percentage) {
        {$_ -ge 90} { "A" }
        {$_ -ge 80} { "B" }
        {$_ -ge 70} { "C" }
        {$_ -ge 60} { "D" }
        default { "F" }
    }
    
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>GitOps TP - Grading Report</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .summary { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; margin: 20px 0; }
        .summary h2 { color: white; margin-top: 0; }
        .grade { font-size: 48px; font-weight: bold; text-align: center; }
        .letter-grade { font-size: 72px; text-align: center; margin: 20px 0; }
        .info { display: flex; justify-content: space-around; margin: 20px 0; }
        .info-box { text-align: center; }
        .info-label { font-size: 14px; opacity: 0.9; }
        .info-value { font-size: 24px; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background: #3498db; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ecf0f1; }
        tr:hover { background: #f8f9fa; }
        .pass { color: #27ae60; font-weight: bold; }
        .fail { color: #e74c3c; font-weight: bold; }
        .category { background: #ecf0f1; font-weight: bold; }
        .chart { margin: 20px 0; }
        .progress { width: 100%; height: 30px; background: #ecf0f1; border-radius: 15px; overflow: hidden; }
        .progress-bar { height: 100%; background: linear-gradient(90deg, #27ae60, #2ecc71); transition: width 0.3s; }
        .timestamp { text-align: center; color: #7f8c8d; margin-top: 30px; font-size: 12px; }
        @media print { .container { box-shadow: none; } }
    </style>
</head>
<body>
    <div class="container">
        <h1>GitOps TP - Automatic Grading Report</h1>
        
        <div class="summary">
            <h2>Overall Grade</h2>
            <div class="letter-grade">$letterGrade</div>
            <div class="grade">$grade / 20</div>
            <div class="info">
                <div class="info-box">
                    <div class="info-label">Total Points</div>
                    <div class="info-value">$($script:TotalPoints) / $($script:MaxPoints)</div>
                </div>
                <div class="info-box">
                    <div class="info-label">Percentage</div>
                    <div class="info-value">$percentage%</div>
                </div>
                <div class="info-box">
                    <div class="info-label">Tests Passed</div>
                    <div class="info-value">$(($script:TestResults | Where-Object Passed).Count) / $($script:TestResults.Count)</div>
                </div>
            </div>
            <div class="progress">
                <div class="progress-bar" style="width: $percentage%"></div>
            </div>
        </div>
        
        $(if ($StudentName -or $StudentID) {
            "<div style='background: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0;'>
                <strong>Student Information</strong><br>
                $(if ($StudentName) { "Name: $StudentName<br>" })
                $(if ($StudentID) { "ID: $StudentID<br>" })
            </div>"
        })
        
        <h2>Grade Breakdown by Category</h2>
        <table>
            <tr>
                <th>Category</th>
                <th>Points Earned</th>
                <th>Max Points</th>
                <th>Percentage</th>
            </tr>
"@
    
    foreach ($category in $GradeCategories.GetEnumerator()) {
        $categoryTests = $script:TestResults | Where-Object { $_.Category -eq $category.Key }
        $earnedPoints = ($categoryTests | Measure-Object -Property Points -Sum).Sum
        $maxPoints = ($categoryTests | Measure-Object -Property MaxPoints -Sum).Sum
        if ($maxPoints -gt 0) {
            $categoryPercentage = [Math]::Round(($earnedPoints / $maxPoints) * 100, 1)
        } else {
            $categoryPercentage = 0
        }
        
        $html += @"
            <tr>
                <td>$($category.Key)</td>
                <td>$earnedPoints</td>
                <td>$maxPoints</td>
                <td>
                    <div style="display: flex; align-items: center;">
                        <div style="flex: 1; background: #ecf0f1; height: 20px; border-radius: 10px; margin-right: 10px;">
                            <div style="width: $categoryPercentage%; height: 100%; background: $(if($categoryPercentage -ge 70){'#27ae60'}elseif($categoryPercentage -ge 50){'#f39c12'}else{'#e74c3c'}); border-radius: 10px;"></div>
                        </div>
                        $categoryPercentage%
                    </div>
                </td>
            </tr>
"@
    }
    
    $html += @"
        </table>
        
        <h2>Detailed Test Results</h2>
        <table>
            <tr>
                <th>Test Name</th>
                <th>Category</th>
                <th>Status</th>
                <th>Points</th>
                <th>Details</th>
            </tr>
"@
    
    foreach ($test in $script:TestResults) {
        $status = if ($test.Passed) { "<span class='pass'>PASS</span>" } else { "<span class='fail'>FAIL</span>" }
        $html += @"
            <tr>
                <td>$($test.TestName)</td>
                <td>$($test.Category)</td>
                <td>$status</td>
                <td>$($test.Points) / $($test.MaxPoints)</td>
                <td>$($test.Details)</td>
            </tr>
"@
    }
    
    $html += @"
        </table>
        
        <h2>Feedback and Recommendations</h2>
        <div style="background: #f8f9fa; padding: 20px; border-radius: 5px;">
"@
    
    # Generate feedback based on performance
    if ($percentage -ge 90) {
        $html += "<p><strong>Excellent work!</strong> You have demonstrated mastery of GitOps concepts and implementation.</p>"
    } elseif ($percentage -ge 80) {
        $html += "<p><strong>Very good!</strong> You have a solid understanding of GitOps principles with minor areas for improvement.</p>"
    } elseif ($percentage -ge 70) {
        $html += "<p><strong>Good effort!</strong> You understand the core concepts but need to strengthen some areas.</p>"
    } elseif ($percentage -ge 60) {
        $html += "<p><strong>Satisfactory.</strong> You have grasped the basics but significant improvements are needed.</p>"
    } else {
        $html += "<p><strong>Needs improvement.</strong> Please review the course materials and practice more.</p>"
    }
    
    # Specific feedback for failed categories
    $failedCategories = @()
    foreach ($category in $GradeCategories.GetEnumerator()) {
        $categoryTests = $script:TestResults | Where-Object { $_.Category -eq $category.Key }
        $earnedPoints = ($categoryTests | Measure-Object -Property Points -Sum).Sum
        $maxPoints = ($categoryTests | Measure-Object -Property MaxPoints -Sum).Sum
        if ($maxPoints -gt 0) {
            $categoryPercentage = ($earnedPoints / $maxPoints) * 100
            if ($categoryPercentage -lt 60) {
                $failedCategories += $category.Key
            }
        }
    }
    
    if ($failedCategories.Count -gt 0) {
        $html += "<h3>Areas needing improvement:</h3><ul>"
        foreach ($category in $failedCategories) {
            $html += "<li><strong>$category:</strong> "
            switch ($category) {
                "Infrastructure" { $html += "Review Docker and Docker Compose configuration. Ensure all services are properly configured and running." }
                "Configuration" { $html += "Check Prometheus and Grafana configurations. Ensure proper datasource and dashboard setup." }
                "Security" { $html += "Implement security scanning with Trivy and Checkov. Follow Docker security best practices." }
                "CICD" { $html += "Complete Jenkins pipeline implementation. Ensure all CI/CD stages are properly configured." }
                "Monitoring" { $html += "Verify all monitoring endpoints are accessible and metrics are being collected." }
                "Documentation" { $html += "Improve documentation quality. Include installation, usage, and architecture details." }
                "BestPractices" { $html += "Implement logging, resource limits, and backup strategies." }
            }
            $html += "</li>"
        }
        $html += "</ul>"
    }
    
    $html += @"
        </div>
        
        <div class="timestamp">
            Report generated on $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")<br>
            GitOps TP Automatic Grading System v1.0.0
        </div>
    </div>
</body>
</html>
"@
    
    # Save HTML report
    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "`n📄 HTML report saved to: $OutputPath" -ForegroundColor Green
    
    # Also save JSON report for programmatic access
    $jsonReport = @{
        StudentName = $StudentName
        StudentID = $StudentID
        TotalPoints = $script:TotalPoints
        MaxPoints = $script:MaxPoints
        Percentage = $percentage
        Grade = $grade
        LetterGrade = $letterGrade
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        TestResults = $script:TestResults
    }
    
    $jsonPath = $OutputPath.Replace(".html", ".json")
    $jsonReport | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonPath -Encoding UTF8
    Write-Host "📄 JSON report saved to: $jsonPath" -ForegroundColor Green
}

# Main Grading Process
function Start-Grading {
    Write-Host @"
╔══════════════════════════════════════════════════════════════╗
║              GitOps TP - Automatic Grading System             ║
║                         Version 1.0.0                         ║
╚══════════════════════════════════════════════════════════════╝
"@ -ForegroundColor Cyan
    
    Write-Host "`n📍 Project Path: $ProjectPath" -ForegroundColor Yellow
    if ($StudentName) { Write-Host "👤 Student Name: $StudentName" -ForegroundColor Yellow }
    if ($StudentID) { Write-Host "🆔 Student ID: $StudentID" -ForegroundColor Yellow }
    Write-Host ""
    
    # Run all tests
    Test-DockerEnvironment
    Test-RunningContainers
    Test-NetworkConfiguration
    Test-VolumeConfiguration
    Test-ServiceEndpoints
    Test-PrometheusConfiguration
    Test-GrafanaConfiguration
    Test-SecurityScanning
    Test-JenkinsPipeline
    Test-TerraformConfiguration
    Test-AnsibleConfiguration
    Test-Documentation
    Test-BestPractices
    
    # Display summary
    Write-Host "`n" -NoNewline
    Write-Host "═" * 60 -ForegroundColor Cyan
    Write-Host "                    GRADING SUMMARY" -ForegroundColor Cyan
    Write-Host "═" * 60 -ForegroundColor Cyan
    
    $percentage = [Math]::Round(($script:TotalPoints / $script:MaxPoints) * 100, 1)
    $grade = [Math]::Round(($script:TotalPoints / $script:MaxPoints) * 20, 2)
    
    Write-Host "Total Points: " -NoNewline
    Write-Host "$($script:TotalPoints) / $($script:MaxPoints)" -ForegroundColor Yellow
    
    Write-Host "Percentage: " -NoNewline
    Write-Host "$percentage%" -ForegroundColor $(if($percentage -ge 70){"Green"}elseif($percentage -ge 50){"Yellow"}else{"Red"})
    
    Write-Host "Final Grade: " -NoNewline
    Write-Host "$grade / 20" -ForegroundColor $(if($grade -ge 14){"Green"}elseif($grade -ge 10){"Yellow"}else{"Red"})
    
    Write-Host "═" * 60 -ForegroundColor Cyan
    
    # Generate report if requested
    if ($GenerateReport) {
        Generate-Report
    }
}

# Run the grading
Start-Grading
