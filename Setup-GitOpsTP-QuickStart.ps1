# ============================================
# GitOps TP - Automatic Grading Script
# File: Grade-GitOpsTP.ps1
# Version: 1.0.1 - Fixed for Windows
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

# Test Result Function
function Write-TestResult {
    param(
        [string]$TestName,
        [int]$Points,
        [int]$MaxPoints,
        [bool]$Passed,
        [string]$Details = ""
    )
    
    $status = if ($Passed) { "[PASS]" } else { "[FAIL]" }
    $color = if ($Passed) { "Green" } else { "Red" }
    
    Write-Host "$status " -NoNewline -ForegroundColor $color
    Write-Host "$TestName " -NoNewline
    Write-Host "[$Points/$MaxPoints points]" -ForegroundColor Yellow
    
    if ($Details -and $Verbose) {
        Write-Host "  Details: $Details" -ForegroundColor Gray
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

# Test Docker Environment
function Test-DockerEnvironment {
    $currentCategory = "Infrastructure"
    Write-Host "`nTesting Docker Environment..." -ForegroundColor Cyan
    
    $dockerRunning = $null -ne (docker version 2>$null)
    Write-TestResult -TestName "Docker daemon running" -Points $(if($dockerRunning){2}else{0}) -MaxPoints 2 -Passed $dockerRunning
    
    $composeInstalled = $null -ne (docker-compose version 2>$null)
    Write-TestResult -TestName "Docker Compose installed" -Points $(if($composeInstalled){2}else{0}) -MaxPoints 2 -Passed $composeInstalled
    
    $composeFile = Test-Path "$ProjectPath\docker-compose.yml"
    Write-TestResult -TestName "docker-compose.yml exists" -Points $(if($composeFile){3}else{0}) -MaxPoints 3 -Passed $composeFile
    
    if ($composeFile) {
        Set-Location $ProjectPath
        $validation = docker-compose config -q 2>&1
        $valid = $LASTEXITCODE -eq 0
        Write-TestResult -TestName "docker-compose.yml valid" -Points $(if($valid){3}else{0}) -MaxPoints 3 -Passed $valid
    }
}

# Test Running Containers
function Test-RunningContainers {
    $currentCategory = "Infrastructure"
    Write-Host "`nTesting Running Containers..." -ForegroundColor Cyan
    
    $requiredContainers = @(
        @{Name="prometheus"; Points=2},
        @{Name="grafana"; Points=2},
        @{Name="jenkins"; Points=2},
        @{Name="node-exporter"; Points=1},
        @{Name="app"; Points=1}
    )
    
    $runningContainers = docker ps --format "{{.Names}}" 2>$null
    
    foreach ($container in $requiredContainers) {
        $containerName = "gitops-$($container.Name)"
        $isRunning = $runningContainers -contains $containerName
        
        if ($isRunning) {
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

# Test Service Endpoints
function Test-ServiceEndpoints {
    $currentCategory = "Monitoring"
    Write-Host "`nTesting Service Endpoints..." -ForegroundColor Cyan
    
    $endpoints = @(
        @{Name="Prometheus"; URL="http://localhost:9090/-/healthy"; Points=3},
        @{Name="Grafana"; URL="http://localhost:3000/api/health"; Points=3},
        @{Name="Jenkins"; URL="http://localhost:8081/login"; Points=3},
        @{Name="Application"; URL="http://localhost:3001/health"; Points=3}
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

# Test Prometheus Configuration
function Test-PrometheusConfiguration {
    $currentCategory = "Configuration"
    Write-Host "`nTesting Prometheus Configuration..." -ForegroundColor Cyan
    
    $configExists = Test-Path "$ProjectPath\config\prometheus\prometheus.yml"
    Write-TestResult -TestName "Prometheus config exists" -Points $(if($configExists){2}else{0}) -MaxPoints 2 -Passed $configExists
    
    try {
        $targetsResponse = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/targets" -TimeoutSec 5
        $activeTargets = $targetsResponse.data.activeTargets
        $allTargetsUp = ($activeTargets | Where-Object { $_.health -ne "up" }).Count -eq 0
        $points = if($allTargetsUp) { 3 } elseif($activeTargets.Count -gt 0) { 2 } else { 0 }
        Write-TestResult -TestName "Prometheus targets" -Points $points -MaxPoints 3 -Passed ($activeTargets.Count -gt 0) -Details "$($activeTargets.Count) targets"
    }
    catch {
        Write-TestResult -TestName "Prometheus targets" -Points 0 -MaxPoints 3 -Passed $false -Details "API not accessible"
    }
}

# Test Security
function Test-SecurityScanning {
    $currentCategory = "Security"
    Write-Host "`nTesting Security Implementation..." -ForegroundColor Cyan
    
    $trivyInstalled = $null -ne (trivy --version 2>$null)
    Write-TestResult -TestName "Trivy scanner available" -Points $(if($trivyInstalled){3}else{0}) -MaxPoints 3 -Passed $trivyInstalled
    
    $checkovInstalled = $null -ne (checkov --version 2>$null)
    Write-TestResult -TestName "Checkov scanner available" -Points $(if($checkovInstalled){3}else{0}) -MaxPoints 3 -Passed $checkovInstalled
    
    $scanReports = Get-ChildItem -Path $ProjectPath -Filter "*security*.json" -Recurse 2>$null
    $hasReports = $scanReports.Count -gt 0
    Write-TestResult -TestName "Security scan reports" -Points $(if($hasReports){4}else{0}) -MaxPoints 4 -Passed $hasReports
}

# Test Jenkins Pipeline
function Test-JenkinsPipeline {
    $currentCategory = "CICD"
    Write-Host "`nTesting Jenkins CI/CD Pipeline..." -ForegroundColor Cyan
    
    $jenkinsfileExists = Test-Path "$ProjectPath\Jenkinsfile"
    Write-TestResult -TestName "Jenkinsfile exists" -Points $(if($jenkinsfileExists){3}else{0}) -MaxPoints 3 -Passed $jenkinsfileExists
    
    try {
        $response = Invoke-WebRequest -Uri "http://localhost:8081/login" -TimeoutSec 5 -UseBasicParsing
        $jenkinsAccessible = $response.StatusCode -eq 200
        Write-TestResult -TestName "Jenkins accessible" -Points $(if($jenkinsAccessible){5}else{0}) -MaxPoints 5 -Passed $jenkinsAccessible
    }
    catch {
        Write-TestResult -TestName "Jenkins accessible" -Points 0 -MaxPoints 5 -Passed $false
    }
}

# Test Documentation
function Test-Documentation {
    $currentCategory = "Documentation"
    Write-Host "`nTesting Documentation..." -ForegroundColor Cyan
    
    $hasReadme = Test-Path "$ProjectPath\README.md"
    Write-TestResult -TestName "README.md exists" -Points $(if($hasReadme){2}else{0}) -MaxPoints 2 -Passed $hasReadme
    
    if ($hasReadme) {
        $readme = Get-Content "$ProjectPath\README.md" -Raw
        $hasContent = $readme.Length -gt 100
        Write-TestResult -TestName "README content" -Points $(if($hasContent){3}else{0}) -MaxPoints 3 -Passed $hasContent
    }
}

# Test Best Practices
function Test-BestPractices {
    $currentCategory = "BestPractices"
    Write-Host "`nTesting Best Practices..." -ForegroundColor Cyan
    
    $hasGitignore = Test-Path "$ProjectPath\.gitignore"
    Write-TestResult -TestName ".gitignore configured" -Points $(if($hasGitignore){1}else{0}) -MaxPoints 1 -Passed $hasGitignore
    
    $envFiles = Get-ChildItem -Path $ProjectPath -Filter "*.env*" -Recurse 2>$null
    $usesEnvVars = $envFiles.Count -gt 0
    Write-TestResult -TestName "Environment variables" -Points $(if($usesEnvVars){1}else{0}) -MaxPoints 1 -Passed $usesEnvVars
}

# Generate Report
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
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .summary { background: #f0f0f0; padding: 20px; border-radius: 10px; margin: 20px 0; }
        .grade { font-size: 48px; font-weight: bold; text-align: center; }
        .letter-grade { font-size: 72px; text-align: center; margin: 20px 0; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background: #3498db; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        .pass { color: green; font-weight: bold; }
        .fail { color: red; font-weight: bold; }
    </style>
</head>
<body>
    <h1>GitOps TP - Grading Report</h1>
    
    <div class="summary">
        <h2>Overall Grade</h2>
        <div class="letter-grade">$letterGrade</div>
        <div class="grade">$grade / 20</div>
        <p>Total Points: $($script:TotalPoints) / $($script:MaxPoints)</p>
        <p>Percentage: $percentage%</p>
    </div>
    
    <h2>Student Information</h2>
    <p>Name: $StudentName</p>
    <p>ID: $StudentID</p>
    <p>Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>
    
    <h2>Detailed Results</h2>
    <table>
        <tr>
            <th>Test Name</th>
            <th>Category</th>
            <th>Status</th>
            <th>Points</th>
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
        </tr>
"@
    }
    
    $html += @"
    </table>
</body>
</html>
"@
    
    $html | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-Host "`nHTML report saved to: $OutputPath" -ForegroundColor Green
    
    # JSON report
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
    Write-Host "JSON report saved to: $jsonPath" -ForegroundColor Green
}

# Main Grading Process
function Start-Grading {
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "        GitOps TP - Automatic Grading System" -ForegroundColor Cyan
    Write-Host "                   Version 1.0.1" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    
    Write-Host "`nProject Path: $ProjectPath" -ForegroundColor Yellow
    if ($StudentName) { Write-Host "Student Name: $StudentName" -ForegroundColor Yellow }
    if ($StudentID) { Write-Host "Student ID: $StudentID" -ForegroundColor Yellow }
    Write-Host ""
    
    # Run all tests
    Test-DockerEnvironment
    Test-RunningContainers
    Test-ServiceEndpoints
    Test-PrometheusConfiguration
    Test-SecurityScanning
    Test-JenkinsPipeline
    Test-Documentation
    Test-BestPractices
    
    # Display summary
    Write-Host "`n============================================================" -ForegroundColor Cyan
    Write-Host "                    GRADING SUMMARY" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    
    $percentage = [Math]::Round(($script:TotalPoints / $script:MaxPoints) * 100, 1)
    $grade = [Math]::Round(($script:TotalPoints / $script:MaxPoints) * 20, 2)
    
    Write-Host "Total Points: $($script:TotalPoints) / $($script:MaxPoints)" -ForegroundColor Yellow
    Write-Host "Percentage: $percentage%" -ForegroundColor $(if($percentage -ge 70){"Green"}elseif($percentage -ge 50){"Yellow"}else{"Red"})
    Write-Host "Final Grade: $grade / 20" -ForegroundColor $(if($grade -ge 14){"Green"}elseif($grade -ge 10){"Yellow"}else{"Red"})
    
    Write-Host "============================================================" -ForegroundColor Cyan
    
    # Generate report if requested
    if ($GenerateReport) {
        Generate-Report
    }
}

# Run the grading
Start-Grading
