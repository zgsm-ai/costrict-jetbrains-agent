@echo off
setlocal enabledelayedexpansion

REM Node.js Detection and Installation Script (Windows)
REM Function: Detect Node.js environment, install builtin version if not exists, check version if exists

set "REQUIRED_VERSION=20.6.0"
set "SCRIPT_DIR=%~dp0"
set "BUILTIN_DIR=%SCRIPT_DIR%..\builtin-nodejs"
REM Install to user's local directory instead of script directory
set "NODE_INSTALL_DIR=%LOCALAPPDATA%\nodejs"

echo =========================================
echo    Node.js Environment Setup Tool
echo =========================================
echo.

REM Detect platform
set "PLATFORM=windows-x64"
echo Platform detected: %PLATFORM%
echo.

REM Check if Node.js is already installed
where node >nul 2>nul
if %errorlevel% equ 0 (
    REM Node.js is installed
    for /f "tokens=*" %%i in ('node -v') do set "CURRENT_VERSION=%%i"
    set "CURRENT_VERSION=!CURRENT_VERSION:v=!"
    
    echo [92m[OK] Node.js version detected: !CURRENT_VERSION![0m
    
    REM Compare versions
    call :CompareVersions !CURRENT_VERSION! %REQUIRED_VERSION%
    
    if !COMPARISON! equ -1 (
        echo [93m[WARNING] Current Node.js version ^(!CURRENT_VERSION!^) is lower than required version ^(%REQUIRED_VERSION%^)[0m
        echo [93mRecommend upgrading to Node.js %REQUIRED_VERSION% or higher[0m
        echo.
        echo You can:
        echo   1. Use nvm to switch version: nvm install %REQUIRED_VERSION% ^&^& nvm use %REQUIRED_VERSION%
        echo   2. Download from https://nodejs.org
        echo   3. Continue with current version (may have compatibility issues^)
    ) else if !COMPARISON! equ 0 (
        echo [92m[OK] Node.js version meets requirements ^(%REQUIRED_VERSION%^)[0m
        echo [92m[OK] You can proceed to the next step![0m
    ) else (
        echo [92m[OK] Node.js version ^(!CURRENT_VERSION!^) is higher than required version ^(%REQUIRED_VERSION%^)[0m
        echo [92m[OK] You can proceed to the next step![0m
    )
) else (
    echo [93mNode.js environment not detected[0m
    
    REM Check if builtin version is already installed
    if exist "%NODE_INSTALL_DIR%\node.exe" (
        echo [92m[OK] Builtin Node.js detected[0m
        for /f "tokens=*" %%i in ('"%NODE_INSTALL_DIR%\node.exe" -v') do set "INSTALLED_VERSION=%%i"
        set "INSTALLED_VERSION=!INSTALLED_VERSION:v=!"
        echo [92mVersion: !INSTALLED_VERSION![0m
        
        REM Auto add to PATH
        call :AddToPath "%NODE_INSTALL_DIR%"
    ) else (
        REM Install builtin Node.js
        call :InstallBuiltinNode
    )
)

echo.
echo =========================================
exit /b 0

:CompareVersions
REM Version comparison function
REM Parameters: %1 = version1, %2 = version2
REM Return: COMPARISON (-1: version1 < version2, 0: version1 = version2, 1: version1 > version2)
set "V1=%~1"
set "V2=%~2"

REM Split version numbers
for /f "tokens=1,2,3 delims=." %%a in ("%V1%") do (
    set "V1_MAJOR=%%a"
    set "V1_MINOR=%%b"
    set "V1_PATCH=%%c"
)

for /f "tokens=1,2,3 delims=." %%a in ("%V2%") do (
    set "V2_MAJOR=%%a"
    set "V2_MINOR=%%b"
    set "V2_PATCH=%%c"
)

REM Compare major version
if !V1_MAJOR! lss !V2_MAJOR! (
    set "COMPARISON=-1"
    exit /b 0
)
if !V1_MAJOR! gtr !V2_MAJOR! (
    set "COMPARISON=1"
    exit /b 0
)

REM Compare minor version
if !V1_MINOR! lss !V2_MINOR! (
    set "COMPARISON=-1"
    exit /b 0
)
if !V1_MINOR! gtr !V2_MINOR! (
    set "COMPARISON=1"
    exit /b 0
)

REM Compare patch version
if !V1_PATCH! lss !V2_PATCH! (
    set "COMPARISON=-1"
    exit /b 0
)
if !V1_PATCH! gtr !V2_PATCH! (
    set "COMPARISON=1"
    exit /b 0
)

REM Versions are equal
set "COMPARISON=0"
exit /b 0

:InstallBuiltinNode
echo [93mNode.js environment not detected, installing builtin Node.js %REQUIRED_VERSION%...[0m

set "ARCHIVE_FILE=%BUILTIN_DIR%\windows-x64\node-v%REQUIRED_VERSION%-win-x64.zip"

if not exist "%ARCHIVE_FILE%" (
    echo [91m[ERROR] Cannot find Node.js installation package for this platform: %ARCHIVE_FILE%[0m
    echo [93mPlease ensure the builtin-nodejs directory contains the Node.js package for your platform[0m
    exit /b 1
)

REM Create installation directory
if not exist "%NODE_INSTALL_DIR%" mkdir "%NODE_INSTALL_DIR%"

REM Extract files
echo Extracting Node.js...

REM Use PowerShell to extract
powershell -Command "Expand-Archive -Path '%ARCHIVE_FILE%' -DestinationPath '%NODE_INSTALL_DIR%' -Force"

REM Move files to unified directory
set "EXTRACT_PATH=%NODE_INSTALL_DIR%\node-v%REQUIRED_VERSION%-win-x64"
if exist "%EXTRACT_PATH%" (
    xcopy "%EXTRACT_PATH%\*" "%NODE_INSTALL_DIR%\" /E /H /Y >nul
    rmdir /S /Q "%EXTRACT_PATH%"
)

echo [92m[OK] Node.js %REQUIRED_VERSION% installed successfully![0m
echo [92mInstallation path: %NODE_INSTALL_DIR%[0m
echo.

REM Auto add to PATH
call :AddToPath "%NODE_INSTALL_DIR%"

exit /b 0

:AddToPath
set "NODE_PATH=%~1"

REM Check if already in PATH (current session)
echo %PATH% | findstr /C:"%NODE_PATH%" >nul 2>nul
if %errorlevel% equ 0 (
    echo [92m[OK] PATH already contains Node.js path[0m
    exit /b 0
)

echo.
echo [93mAutomatically adding Node.js to PATH environment variable...[0m

REM Get current user PATH
for /f "skip=2 tokens=3*" %%a in ('reg query "HKCU\Environment" /v PATH 2^>nul') do set "USER_PATH=%%b"

REM Check if already exists in user PATH
echo %USER_PATH% | findstr /C:"%NODE_PATH%" >nul 2>nul
if %errorlevel% equ 0 (
    echo [92m[OK] Node.js path already exists in user environment variables[0m
    REM Still add to current session if not there
    set "PATH=%NODE_PATH%;%PATH%"
    echo [92m[OK] Current session updated[0m
    exit /b 0
)

REM If user PATH is empty, set directly
if "%USER_PATH%"=="" (
    setx PATH "%NODE_PATH%" >nul 2>nul
) else (
    REM Add to beginning of PATH
    setx PATH "%NODE_PATH%;%USER_PATH%" >nul 2>nul
)

if %errorlevel% equ 0 (
    echo [92m[OK] Successfully added to user PATH environment variable[0m
    echo [93mNote: New Command Prompt windows will have Node.js in PATH[0m
    echo.
    
    REM Make effective in current session
    set "PATH=%NODE_PATH%;%PATH%"
    echo [92m[OK] Current session updated, you can use 'node' command directly[0m
) else (
    echo [91m[ERROR] Failed to add automatically[0m
    echo [93mYou can manually add to PATH:[0m
    echo   setx PATH "%NODE_PATH%;%%PATH%%"
    echo.
    echo Or through GUI:
    echo   1. Right-click "This PC" -^> "Properties"
    echo   2. Click "Advanced system settings"
    echo   3. Click "Environment Variables"
    echo   4. Find "Path" in user variables, add: %NODE_PATH%
)

exit /b 0
