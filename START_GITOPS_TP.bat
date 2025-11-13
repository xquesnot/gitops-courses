@echo off
REM ============================================
REM GitOps TP - Quick Start Script for Windows
REM File: START_GITOPS_TP.bat
REM Version: 1.0.0
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

REM Set colors
set RED=[91m
set GREEN=[92m
set YELLOW=[93m
set BLUE=[94m
set MAGENTA=[95m
set CYAN=[96m
set WHITE=[97m
set RESET=[0m

cls
echo %CYAN%
echo ============================================================
echo                   GitOps TP - Quick Installer
echo                        Version 1.0.0
echo                   DevOps Master Course 2024
echo ============================================================
echo %RESET%
echo.

:MENU
echo %YELLOW%Select an option:%RESET%
echo.
echo   %CYAN%1.%RESET% Complete Installation (Docker + Project)
echo   %CYAN%2.%RESET% Install Docker Desktop only
echo   %CYAN%3.%RESET% Setup Project (Docker already installed)
echo   %CYAN%4.%RESET% Start GitOps Stack
echo   %CYAN%5.%RESET% Stop GitOps Stack
echo   %CYAN%6.%RESET% Run Automatic Grading
echo   %CYAN%7.%RESET% View Service Status
echo   %CYAN%8.%RESET% Clean Everything (Uninstall)
echo   %CYAN%9.%RESET% View Logs
echo   %CYAN%0.%RESET% Exit
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

echo %RED%Invalid choice! Please try again.%RESET%
timeout /t 2 >nul
cls
goto MENU

:COMPLETE_INSTALL
echo.
echo %CYAN%Starting Complete Installation...%RESET%
echo ============================================================

REM Check if Docker is installed
docker --version >nul 2>&1
if %errorLevel% neq 0 (
    echo %YELLOW%Docker not found. Installing Docker Desktop...%RESET%
    call :INSTALL_DOCKER_FUNC
) else (
    echo %GREEN%Docker is already installed.%RESET%
)

call :SETUP_PROJECT_FUNC
call :START_STACK_FUNC
goto SHOW_URLS

:INSTALL_DOCKER
echo.
echo %CYAN%Installing Docker Desktop...%RESET%
call :INSTALL_DOCKER_FUNC
echo.
echo %YELLOW%Please restart your computer and run this script again.%RESET%
pause
exit /b 0

:SETUP_PROJECT
echo.
echo %CYAN%Setting up GitOps Project...%RESET%
call :SETUP_PROJECT_FUNC
goto MENU_RETURN

:START_STACK
echo.
echo %CYAN%Starting GitOps Stack...%RESET%
call :START_STACK_FUNC
goto SHOW_URLS

:STOP_STACK
echo.
echo %CYAN%Stopping GitOps Stack...%RESET%
cd /d C:\GitOpsTP
docker-compose down
echo %GREEN%Stack stopped successfully.%RESET%
goto MENU_RETURN

:RUN_GRADING
echo.
echo %CYAN%Running Automatic Grading...%RESET%
echo.
set /p studentName="Enter student name (optional): "
set /p studentID="Enter student ID (optional): "
echo.
powershell -ExecutionPolicy Bypass -File "C:\GitOpsTP\Grade-GitOpsTP.ps1" -StudentName "%studentName%" -StudentID "%studentID%"
echo.
echo %GREEN%Grading complete! Check the report in C:\GitOpsTP\grading-report.html%RESET%
start C:\GitOpsTP\grading-report.html
goto MENU_RETURN

:VIEW_STATUS
echo.
echo %CYAN%Service Status:%RESET%
echo ============================================================
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo.
echo %CYAN%Network Status:%RESET%
docker network ls
echo.
echo %CYAN%Volume Status:%RESET%
docker volume ls
goto MENU_RETURN

:CLEAN_ALL
echo.
echo %RED%WARNING: This will remove all GitOps TP components!%RESET%
set /p confirm="Are you sure? (yes/no): "
if /i "%confirm%"=="yes" (
    echo %YELLOW%Cleaning up...%RESET%
    cd /d C:\GitOpsTP
    docker-compose down -v
    docker system prune -af
    cd /d C:\
    rmdir /s /q C:\GitOpsTP
    echo %GREEN%Cleanup complete.%RESET%
) else (
    echo %YELLOW%Cleanup cancelled.%RESET%
)
goto MENU_RETURN

:VIEW_LOGS
echo.
echo %CYAN%Select service to view logs:%RESET%
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
echo %GREEN%Docker Desktop installed successfully.%RESET%
exit /b 0

:SETUP_PROJECT_FUNC
echo Creating project directory...
if not exist C:\GitOpsTP mkdir C:\GitOpsTP

echo Checking for PowerShell script...
if not exist C:\GitOpsTP\Install-GitOpsTP.ps1 (
    echo Downloading installation script...
    powershell -Command "Invoke-WebRequest -Uri 'https://raw.githubusercontent.com/your-repo/Install-GitOpsTP.ps1' -OutFile 'C:\GitOpsTP\Install-GitOpsTP.ps1'"
)

echo Running PowerShell installation script...
powershell -ExecutionPolicy Bypass -File "C:\GitOpsTP\Install-GitOpsTP.ps1" -AutoStart:$false

echo %GREEN%Project setup complete.%RESET%
exit /b 0

:START_STACK_FUNC
cd /d C:\GitOpsTP
echo Pulling Docker images (this may take a while)...
docker-compose pull
echo Starting services...
docker-compose up -d
echo Waiting for services to be ready...
timeout /t 15 >nul
echo %GREEN%Stack started successfully.%RESET%
exit /b 0

:SHOW_URLS
echo.
echo %GREEN%============================================================%RESET%
echo %GREEN%          GitOps Stack is Ready!%RESET%
echo %GREEN%============================================================%RESET%
echo.
echo %CYAN%Service URLs:%RESET%
echo   Prometheus:  %YELLOW%http://localhost:9090%RESET%
echo   Grafana:     %YELLOW%http://localhost:3000%RESET% (admin/gitops2024)
echo   Jenkins:     %YELLOW%http://localhost:8081%RESET% (admin/jenkins2024)
echo   SonarQube:   %YELLOW%http://localhost:9000%RESET% (admin/admin)
echo   Application: %YELLOW%http://localhost:3001%RESET%
echo.
echo %CYAN%Quick Actions:%RESET%
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
echo %CYAN%Thank you for using GitOps TP!%RESET%
echo.
timeout /t 2 >nul
exit /b 0
