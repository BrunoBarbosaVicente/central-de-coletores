@echo off
title Central de Coletores - Servidor Local
echo Iniciando servidor...
powershell -ExecutionPolicy Bypass -File "%~dp0Servidor_Central.ps1"
pause