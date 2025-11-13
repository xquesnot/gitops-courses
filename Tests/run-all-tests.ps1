# Run all tests
Write-Host "Running all tests..." -ForegroundColor Cyan

# Test Docker
docker version
if ($?) { Write-Host "✅ Docker OK" -ForegroundColor Green }

# Test services
$services = @("prometheus", "grafana", "jenkins")
foreach ($service in $services) {
    docker ps | Select-String $service
    if ($?) { Write-Host "✅ $service OK" -ForegroundColor Green }
}

# Test endpoints
Invoke-WebRequest -Uri "http://localhost:9090" -UseBasicParsing
if ($?) { Write-Host "✅ Prometheus endpoint OK" -ForegroundColor Green }

Write-Host "All tests completed!" -ForegroundColor Green
