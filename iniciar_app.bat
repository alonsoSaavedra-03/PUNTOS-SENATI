@echo off
title Lanzador Aula Puntos - SENATI
echo ===================================================
echo   Iniciando Aula Puntos - SENATI con MySQL (XAMPP)
echo ===================================================

cd /d "%~dp0"

echo 1. Iniciando Servidor Backend API REST (Puerto 8080)...
start "Backend - Aula Puntos (MySQL)" cmd /k "cd /d "%~dp0" && dart run backend/server.dart"

timeout /t 3 /nobreak >nul

echo 2. Iniciando Servidor Web Frontend (Puerto 8765)...
start "Frontend - Aula Puntos" cmd /k "cd /d "%~dp0" && node serve_aulapuntos.mjs"

timeout /t 2 /nobreak >nul

echo 3. Abriendo la aplicacion en tu navegador...
start http://localhost:8765

echo ===================================================
echo   Listo! La app se ha abierto en tu navegador.
echo ===================================================
