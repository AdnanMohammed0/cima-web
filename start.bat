@echo off
title WatchParty
cls

echo ============================================
echo        WatchParty - Starting Application
echo ============================================
echo.

:: Check Node.js
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Node.js not found. Please install Node.js from https://nodejs.org
    pause
    exit /b 1
)
echo [OK] Node.js found

:: Check npm
where npm >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] npm not found.
    pause
    exit /b 1
)
echo [OK] npm found
echo.

:: Kill any existing node processes on our ports
echo Cleaning up old servers...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :5000') do (
    taskkill /f /pid %%a >nul 2>nul
)
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :5173') do (
    taskkill /f /pid %%a >nul 2>nul
)
timeout /t 1 /nobreak >nul
echo.

:: Install backend dependencies if needed
if not exist "%~dp0backend\node_modules" (
    echo [1/4] Installing backend dependencies...
    cd /d "%~dp0backend"
    call npm install
    if %errorlevel% neq 0 (
        echo [ERROR] Backend install failed
        pause
        exit /b 1
    )
) else (
    echo [1/4] Backend dependencies ready
)

:: Install frontend dependencies if needed
if not exist "%~dp0frontend\node_modules" (
    echo [2/4] Installing frontend dependencies...
    cd /d "%~dp0frontend"
    call npm install
    if %errorlevel% neq 0 (
        echo [ERROR] Frontend install failed
        pause
        exit /b 1
    )
) else (
    echo [2/4] Frontend dependencies ready
)

:: Start backend (port 5000)
echo [3/4] Starting backend server...
start "WatchParty-Backend" cmd /c "cd /d "%~dp0backend" && node server.js"
timeout /t 2 /nobreak >nul

:: Start frontend dev server (port 5173)
echo [4/4] Starting frontend dev server...
start "WatchParty-Frontend" cmd /c "cd /d "%~dp0frontend" && call npx.cmd vite"

echo.
echo ============================================
echo        Both servers are starting up!
echo ============================================
echo.
echo  Backend API : http://localhost:5000
echo  Frontend App: http://localhost:5173
echo.
echo  Open http://localhost:5173 in your browser
echo.
echo  NOTE: The frontend takes ~5-10 seconds
echo        to start after the backend.
echo.
echo  Close both servers with Ctrl+C in each
echo  server window, or close the windows.
echo.
echo ============================================
echo.
pause
