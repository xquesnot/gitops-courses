@echo off
REM ============================================
REM GitOps TP - Quick Start Script for Windows
REM File: START_GITOPS_TP.bat
REM Version: 1.0.2 - Fixed ANSI codes
REM ============================================

setlocal enabledelayedexpansion
title GitOps TP - Installation and Setup

REM Check for admin rights
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo.
    echo ========================================
    echo  ERROR: Administrator rights required!
    echo ========================================
    echo.
    echo Please run this script as Administrator
    echo Right-click and select "Run as administrator"
    echo.
    pause
    exit /b 1
)

cls
echo ============================================================
echo                   GitOps TP - Quick Installer
echo                        Version 1.0.2
echo                   DevOps Master Course 2024
echo ============================================================
echo.

:MENU
echo Select an option:
echo.
echo   1. Complete Installation (Docker + Project)
echo   2. Install Docker Desktop only
echo   3. Setup Project (Docker already installed)
echo   4. Start GitOps Stack
echo   5. Stop GitOps Stack
echo   6. Run Automatic Grading
echo   7. View Service Status
echo   8. Clean Everything (Uninstall)
echo   9. View Logs
echo   0. Exit
echo.
set /p choice="Enter your choice (0-9): "

if "%choice%"=="1" goto COMPLETE_INSTALL
if "%choice%"=="2" goto INSTALL_DOCKER
if "%choice%"=="3" goto SETUP_PROJECT
if "%choice%"=="4" goto START_STACK
if "%choice%"=="5" goto STOP_STACK
if "%choice%"=="6" goto RUN_GRADING
if "%choice%"=="7" goto VIEW_STATUS
if "%choice%"=="8" goto CLEAN_ALL
if "%choice%"=="9" goto VIEW_LOGS
if "%choice%"=="0" goto EXIT

echo Invalid choice! Please try again.
timeout /t 2 >nul
cls
goto MENU

:COMPLETE_INSTALL
echo.
echo Starting Complete Installation...
echo ============================================================

REM Check if Docker is installed
docker --version >nul 2>&1
if %errorLevel% neq 0 (
    echo Docker not found. Installing Docker Desktop...
    call :INSTALL_DOCKER_FUNC
) else (
    echo Docker is already installed.
)

call :SETUP_PROJECT_FUNC
call :START_STACK_FUNC
goto SHOW_URLS

:INSTALL_DOCKER
echo.
echo Installing Docker Desktop...
call :INSTALL_DOCKER_FUNC
echo.
echo Please restart your computer and run this script again.
pause
exit /b 0

:SETUP_PROJECT
echo.
echo Setting up GitOps Project...
call :SETUP_PROJECT_FUNC
goto MENU_RETURN

:START_STACK
echo.
echo Starting GitOps Stack...
call :START_STACK_FUNC
goto SHOW_URLS

:STOP_STACK
echo.
echo Stopping GitOps Stack...
cd /d C:\GitOpsTP
docker-compose down
echo Stack stopped successfully.
goto MENU_RETURN

:RUN_GRADING
echo.
echo Running Automatic Grading...
echo.
set /p studentName="Enter student name (optional): "
set /p studentID="Enter student ID (optional): "
echo.
powershell -ExecutionPolicy Bypass -File "C:\GitOpsTP\Scripts\Grade-GitOpsTP.ps1" -StudentName "%studentName%" -StudentID "%studentID%"
echo.
echo Grading complete! Check the report in C:\GitOpsTP\grading-report.html
start C:\GitOpsTP\grading-report.html
goto MENU_RETURN

:VIEW_STATUS
echo.
echo Service Status:
echo ============================================================
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo.
echo Network Status:
docker network ls
echo.
echo Volume Status:
docker volume ls
goto MENU_RETURN

:CLEAN_ALL
echo.
echo WARNING: This will remove all GitOps TP components!
set /p confirm="Are you sure? (yes/no): "
if /i "%confirm%"=="yes" (
    echo Cleaning up...
    cd /d C:\GitOpsTP
    docker-compose down -v
    docker system prune -af
    cd /d C:\
    rmdir /s /q C:\GitOpsTP
    echo Cleanup complete.
) else (
    echo Cleanup cancelled.
)
goto MENU_RETURN

:VIEW_LOGS
echo.
echo Select service to view logs:
echo   1. Prometheus
echo   2. Grafana
echo   3. Jenkins
echo   4. Application
echo   5. All services
echo   0. Back to menu
echo.
set /p logChoice="Enter choice: "

cd /d C:\GitOpsTP
if "%logChoice%"=="1" docker logs -f gitops-prometheus
if "%logChoice%"=="2" docker logs -f gitops-grafana
if "%logChoice%"=="3" docker logs -f gitops-jenkins
if "%logChoice%"=="4" docker logs -f gitops-app
if "%logChoice%"=="5" docker-compose logs -f
goto MENU_RETURN

:INSTALL_DOCKER_FUNC
echo Downloading Docker Desktop...
powershell -Command "Invoke-WebRequest -Uri 'https://desktop.docker.com/win/stable/Docker Desktop Installer.exe' -OutFile '%TEMP%\DockerDesktopInstaller.exe'"
echo Installing Docker Desktop (this may take several minutes)...
start /wait "" "%TEMP%\DockerDesktopInstaller.exe" install --quiet
del "%TEMP%\DockerDesktopInstaller.exe"
echo Docker Desktop installed successfully.
exit /b 0

:SETUP_PROJECT_FUNC
echo Creating project directory...
if not exist C:\GitOpsTP mkdir C:\GitOpsTP

echo Copying files...
xcopy /E /I /Y "%~dp0*" "C:\GitOpsTP\" >nul 2>&1

echo Running PowerShell installation script...
powershell -ExecutionPolicy Bypass -File "C:\GitOpsTP\Installation\Install-GitOpsTP.ps1" -AutoStart:$false

echo Project setup complete.
exit /b 0

:START_STACK_FUNC
cd /d C:\GitOpsTP
echo Pulling Docker images (this may take a while)...
docker-compose pull
echo Starting services...
docker-compose up -d
echo Waiting for services to be ready...
timeout /t 15 >nul
echo Stack started successfully.
exit /b 0

:SHOW_URLS
echo.
echo ============================================================
echo           GitOps Stack is Ready!
echo ============================================================
echo.
echo Service URLs:
echo   Prometheus:  http://localhost:9090
echo   Grafana:     http://localhost:3000 (admin/gitops2024)
echo   Jenkins:     http://localhost:8081 (admin/jenkins2024)
echo   Application: http://localhost:3001
echo.
echo Quick Actions:
echo   View Status:  docker-compose ps
echo   View Logs:    docker-compose logs -f
echo   Stop Stack:   docker-compose down
echo.

:MENU_RETURN
echo.
echo Press any key to return to menu...
pause >nul
cls
goto MENU

:EXIT
echo.
echo Thank you for using GitOps TP!
echo.
timeout /t 2 >nul
exit /b 0
