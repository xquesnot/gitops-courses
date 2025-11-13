# ============================================
# GitOps TP - Automated Functional Tests
# File: Test-GitOpsTP.ps1
# Version: 1.0.0
# ============================================

param(
    [string]$ProjectPath = "C:\GitOpsTP",
    [switch]$FullTest = $false,
    [int]$Timeout = 300
)

$script:TestsPassed = 0
$script:TestsFailed = 0
$script:StartTime = Get-Date

function Write-TestHeader { 
    param([string]$Text)
    Write-Host "`n══════════════════════════════" -ForegroundColor Cyan
    Write-Host " $Text" -ForegroundColor Cyan
    Write-Host "══════════════════════════════" -ForegroundColor Cyan
}

function Test-ServiceHealth {
    Write-TestHeader "Service Health Tests"
    
    $services = @(
        @{Name="Prometheus"; URL="http://localhost:9090/-/healthy"; Expected="Prometheus is Healthy"},
        @{Name="Grafana"; URL="http://localhost:3000/api/health"; Expected="ok"},
        @{Name="Jenkins"; URL="http://localhost:8081/login"; Expected="Jenkins"},
        @{Name="Application"; URL="http://localhost:3001/health"; Expected="healthy"}
    )
    
    foreach ($service in $services) {
        try {
            $response = Invoke-WebRequest -Uri $service.URL -TimeoutSec 5 -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Host "  ✅ $($service.Name) is healthy" -ForegroundColor Green
                $script:TestsPassed++
            }
        }
        catch {
            Write-Host "  ❌ $($service.Name) is not responding" -ForegroundColor Red
            $script:TestsFailed++
        }
    }
}

function Test-MetricsCollection {
    Write-TestHeader "Metrics Collection Tests"
    
    try {
        $response = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/query?query=up" -TimeoutSec 5
        $upTargets = $response.data.result | Where-Object { $_.value[1] -eq "1" }
        
        Write-Host "  ✅ Prometheus collecting metrics: $($upTargets.Count) targets up" -ForegroundColor Green
        $script:TestsPassed++
        
        foreach ($target in $upTargets) {
            Write-Host "    • $($target.metric.job): UP" -ForegroundColor Gray
        }
    }
    catch {
        Write-Host "  ❌ Failed to query Prometheus metrics" -ForegroundColor Red
        $script:TestsFailed++
    }
}

function Test-ContainerStatus {
    Write-TestHeader "Container Status Tests"
    
    $containers = docker ps --format "json" 2>$null | ConvertFrom-Json
    $gitopsContainers = $containers | Where-Object { $_.Names -like "gitops-*" }
    
    if ($gitopsContainers.Count -gt 0) {
        Write-Host "  ✅ Found $($gitopsContainers.Count) GitOps containers running" -ForegroundColor Green
        $script:TestsPassed++
        
        foreach ($container in $gitopsContainers) {
            $health = docker inspect $container.Names --format='{{.State.Health.Status}}' 2>$null
            $status = if ($health) { $health } else { "running" }
            Write-Host "    • $($container.Names): $status" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "  ❌ No GitOps containers found" -ForegroundColor Red
        $script:TestsFailed++
    }
}

function Test-SecurityScans {
    Write-TestHeader "Security Scan Tests"
    
    # Test Trivy availability
    $trivyVersion = trivy version 2>$null
    if ($trivyVersion) {
        Write-Host "  ✅ Trivy scanner available" -ForegroundColor Green
        $script:TestsPassed++
        
        # Quick scan on a small image
        Write-Host "    Running quick security scan..." -ForegroundColor Gray
        $scanResult = trivy image --severity CRITICAL --quiet alpine:latest 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ Security scan completed successfully" -ForegroundColor Green
            $script:TestsPassed++
        }
    }
    else {
        Write-Host "  ⚠️ Trivy not installed (optional)" -ForegroundColor Yellow
    }
}

function Test-NetworkConnectivity {
    Write-TestHeader "Network Connectivity Tests"
    
    $network = docker network inspect gitops-network 2>$null | ConvertFrom-Json
    if ($network) {
        Write-Host "  ✅ GitOps network exists" -ForegroundColor Green
        $script:TestsPassed++
        
        $containers = $network.Containers.PSObject.Properties.Name
        Write-Host "    Connected containers: $($containers.Count)" -ForegroundColor Gray
    }
    else {
        Write-Host "  ❌ GitOps network not found" -ForegroundColor Red
        $script:TestsFailed++
    }
}

function Test-DataPersistence {
    Write-TestHeader "Data Persistence Tests"
    
    $volumes = docker volume ls --format "{{.Name}}" 2>$null
    $gitopsVolumes = $volumes | Where-Object { $_ -like "*prometheus*" -or $_ -like "*grafana*" -or $_ -like "*jenkins*" }
    
    if ($gitopsVolumes.Count -gt 0) {
        Write-Host "  ✅ Found $($gitopsVolumes.Count) persistent volumes" -ForegroundColor Green
        $script:TestsPassed++
        
        foreach ($volume in $gitopsVolumes) {
            $info = docker volume inspect $volume 2>$null | ConvertFrom-Json
            $size = if ($info.UsageData) { "$([Math]::Round($info.UsageData.Size/1MB, 2)) MB" } else { "N/A" }
            Write-Host "    • $volume : $size" -ForegroundColor Gray
        }
    }
    else {
        Write-Host "  ❌ No persistent volumes found" -ForegroundColor Red
        $script:TestsFailed++
    }
}

function Test-APIEndpoints {
    Write-TestHeader "API Endpoint Tests"
    
    # Test Prometheus API
    try {
        $labels = Invoke-RestMethod -Uri "http://localhost:9090/api/v1/labels" -TimeoutSec 5
        Write-Host "  ✅ Prometheus API: $($labels.data.Count) labels available" -ForegroundColor Green
        $script:TestsPassed++
    }
    catch {
        Write-Host "  ❌ Prometheus API not accessible" -ForegroundColor Red
        $script:TestsFailed++
    }
    
    # Test Grafana API
    try {
        $headers = @{
            "Authorization" = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:gitops2024"))
        }
        $datasources = Invoke-RestMethod -Uri "http://localhost:3000/api/datasources" -Headers $headers -TimeoutSec 5
        Write-Host "  ✅ Grafana API: $($datasources.Count) datasources configured" -ForegroundColor Green
        $script:TestsPassed++
    }
    catch {
        Write-Host "  ❌ Grafana API not accessible" -ForegroundColor Red
        $script:TestsFailed++
    }
}

function Test-LoadBalancing {
    if ($FullTest) {
        Write-TestHeader "Load Testing"
        
        Write-Host "  Running load test on application..." -ForegroundColor Gray
        $results = @()
        
        for ($i = 1; $i -le 100; $i++) {
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            try {
                $response = Invoke-WebRequest -Uri "http://localhost:3001/" -TimeoutSec 2 -UseBasicParsing
                $stopwatch.Stop()
                $results += $stopwatch.ElapsedMilliseconds
            }
            catch {
                # Ignore failures for load test
            }
        }
        
        if ($results.Count -gt 0) {
            $avg = ($results | Measure-Object -Average).Average
            $max = ($results | Measure-Object -Maximum).Maximum
            $min = ($results | Measure-Object -Minimum).Minimum
            
            Write-Host "  ✅ Load test completed: $($results.Count)/100 successful" -ForegroundColor Green
            Write-Host "    • Average response: $([Math]::Round($avg, 2))ms" -ForegroundColor Gray
            Write-Host "    • Min/Max: $min ms / $max ms" -ForegroundColor Gray
            $script:TestsPassed++
        }
    }
}

function Show-TestSummary {
    $duration = (Get-Date) - $script:StartTime
    $totalTests = $script:TestsPassed + $script:TestsFailed
    $successRate = if ($totalTests -gt 0) { [Math]::Round(($script:TestsPassed / $totalTests) * 100, 1) } else { 0 }
    
    Write-Host "`n══════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "         TEST EXECUTION SUMMARY" -ForegroundColor Cyan
    Write-Host "══════════════════════════════════════" -ForegroundColor Cyan
    
    Write-Host "Total Tests: $totalTests" -ForegroundColor White
    Write-Host "Passed: " -NoNewline
    Write-Host "$script:TestsPassed" -ForegroundColor Green
    Write-Host "Failed: " -NoNewline
    Write-Host "$script:TestsFailed" -ForegroundColor Red
    Write-Host "Success Rate: " -NoNewline
    
    $color = if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 60) { "Yellow" } else { "Red" }
    Write-Host "$successRate%" -ForegroundColor $color
    
    Write-Host "Duration: $([Math]::Round($duration.TotalSeconds, 2)) seconds" -ForegroundColor White
    Write-Host "══════════════════════════════════════" -ForegroundColor Cyan
    
    # Exit code based on success
    if ($script:TestsFailed -eq 0) {
        Write-Host "`n✅ All tests passed successfully!" -ForegroundColor Green
        exit 0
    }
    else {
        Write-Host "`n❌ Some tests failed. Please review the results." -ForegroundColor Red
        exit 1
    }
}

# Main Test Execution
Write-Host "╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     GitOps TP - Functional Tests     ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""
Write-Host "Project Path: $ProjectPath" -ForegroundColor Yellow
Write-Host "Full Test: $FullTest" -ForegroundColor Yellow
Write-Host ""

# Change to project directory
if (Test-Path $ProjectPath) {
    Set-Location $ProjectPath
}
else {
    Write-Host "❌ Project path not found: $ProjectPath" -ForegroundColor Red
    exit 1
}

# Run all tests
Test-ServiceHealth
Test-MetricsCollection
Test-ContainerStatus
Test-NetworkConnectivity
Test-DataPersistence
Test-APIEndpoints
Test-SecurityScans
Test-LoadBalancing

# Show summary
Show-TestSummary
