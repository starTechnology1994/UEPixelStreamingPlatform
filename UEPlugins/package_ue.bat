@echo off
title UE Package Tool (PSView)

:: ============================================================
::  UE PSView Package Script
::  Usage:
::    package_ue.bat                 Show usage
::    package_ue.bat all             Package all 8 versions (Win64 + Linux)
::    package_ue.bat all Win64       Package all 8 versions, Windows only
::    package_ue.bat all Linux       Package all 8 versions, Linux only
::    package_ue.bat 58              Package single version (Win64 + Linux)
::    package_ue.bat 58 Win64        Package single version, Windows only
::    package_ue.bat 58 Linux        Package single version, Linux only
:: ============================================================

setlocal EnableDelayedExpansion

set "MODE=%~1"
set "PLATFORM=%~2"
set "VERSIONS=51 52 53 54 55 56 57 58"

:: ---- validate mode ----
if "%MODE%"=="" goto :usage
if /i "%MODE%"=="help" goto :usage
if /i not "%MODE%"=="all" (
    echo %MODE%| findstr /r "^5[1-8]$" >nul
    if errorlevel 1 goto :usage
)
:: ---- validate platform ----
if not "%PLATFORM%"=="" (
    if /i not "%PLATFORM%"=="Win64" if /i not "%PLATFORM%"=="Linux" goto :usage
)

set "FAILED=0"
set "SUCCEED=0"

if /i "%MODE%"=="all" (
    echo ============================================
    echo   Packing ALL versions 5.1 - 5.8
    echo   Platform: %PLATFORM%  [empty = both]
    echo ============================================
    echo.
    for %%v in (%VERSIONS%) do (
        call :do_package %%v
    )
    goto :summary
)

call :do_package %MODE%
goto :summary

:usage
echo Usage: package_ue.bat ^<version^|all^> [Win64^|Linux]
echo.
echo   package_ue.bat all            Package all 8 versions, both platforms
echo   package_ue.bat all Win64      Package all 8 versions, Windows only
echo   package_ue.bat all Linux      Package all 8 versions, Linux only
echo   package_ue.bat 58             Package single version, both platforms
echo   package_ue.bat 58 Win64       Package single version, Windows only
echo   package_ue.bat 58 Linux       Package single version, Linux only
echo.
echo   Versions: 51 52 53 54 55 56 57 58
echo   Projects: E:\UEProjects\UE{VER}_PSView
exit /b 1

:do_package
set "VER=%~1"

:: UE installation paths (51/52/53/58 on C:, 54/55/56/57 on D:)
if "%VER%"=="51" set "UE_DIR=C:\Program Files\Epic Games\UE_5.1"
if "%VER%"=="52" set "UE_DIR=C:\Program Files\Epic Games\UE_5.2"
if "%VER%"=="53" set "UE_DIR=C:\Program Files\Epic Games\UE_5.3"
if "%VER%"=="54" set "UE_DIR=D:\Program Files\Epic Games\UE_5.4"
if "%VER%"=="55" set "UE_DIR=D:\Program Files\Epic Games\UE_5.5"
if "%VER%"=="56" set "UE_DIR=D:\Program Files\Epic Games\UE_5.6"
if "%VER%"=="57" set "UE_DIR=D:\Program Files\Epic Games\UE_5.7"
if "%VER%"=="58" set "UE_DIR=C:\Program Files\Epic Games\UE_5.8"

set "PROJ_DIR=E:\UEProjects\UE%VER%_PSView"
set "PROJ=%PROJ_DIR%\UE%VER%_PSView.uproject"
set "ARCHIVE=%PROJ_DIR%\Release"
set "UAT=%UE_DIR%\Engine\Build\BatchFiles\RunUAT.bat"
set "BUILD=%UE_DIR%\Engine\Build\BatchFiles\Build.bat"

:: Linux toolchains
if "%VER%"=="51" set "TOOLCHAIN=v20_clang-13.0.1-centos7"
if "%VER%"=="52" set "TOOLCHAIN=v21_clang-15.0.1-centos7"
if "%VER%"=="53" set "TOOLCHAIN=v22_clang-16.0.6-centos7"
if "%VER%"=="54" set "TOOLCHAIN=v22_clang-16.0.6-centos7"
if "%VER%"=="55" set "TOOLCHAIN=v23_clang-18.1.0-rockylinux8"
if "%VER%"=="56" set "TOOLCHAIN=v25_clang-18.1.0-rockylinux8"
if "%VER%"=="57" set "TOOLCHAIN=v26_clang-20.1.8-rockylinux8"
if "%VER%"=="58" set "TOOLCHAIN=v26_clang-20.1.8-rockylinux8"
set "LINUX_TOOLCHAIN=C:\UnrealToolchains\%TOOLCHAIN%"

:: UE 5.7 / 5.8 precompiled engine modules use MSVC 14.44, but UAT does not
:: forward -CompilerVersion to UBT, so we precompile the Game target with
:: Build.bat first, then cook/stage/pak/archive without compiling.
set "EXTRA="
if "%VER%"=="57" set "EXTRA=-CompilerVersion=14.44.35207"
if "%VER%"=="58" set "EXTRA=-CompilerVersion=14.44.35207"

if not exist "%UE_DIR%" (
    echo [ERROR] UE not installed: %UE_DIR%
    set /a FAILED+=1
    goto :eof
)
if not exist "%PROJ%" (
    echo [ERROR] Project not found: %PROJ%
    set /a FAILED+=1
    goto :eof
)

set "DO_WIN64=0"
set "DO_LINUX=0"
if "%PLATFORM%"=="" (
    set "DO_WIN64=1"
    set "DO_LINUX=1"
)
if /i "%PLATFORM%"=="Win64" set "DO_WIN64=1"
if /i "%PLATFORM%"=="Linux" set "DO_LINUX=1"

echo.
echo ============================================
echo   UE5.%VER:~1% Package
echo ============================================
echo   Editor : %UE_DIR%
echo   Project: %PROJ%
echo   Output : %ARCHIVE%
echo   Target :
if %DO_WIN64%==1 echo            - Win64
if %DO_LINUX%==1 echo            - Linux
echo ============================================
echo.

set "STEP=0"

:: ---------------- Win64 ----------------
if %DO_WIN64%==0 goto :skip_win
set /a STEP+=1
echo [%STEP%] Packaging Win64 ...
echo.

:: UE 5.7 / 5.8: precompile Game target with Build.bat (passes -CompilerVersion
:: to UBT), then let UAT cook/stage/pak/archive WITHOUT compiling.
set "TWO_STEP=0"
if "%VER%"=="57" set "TWO_STEP=1"
if "%VER%"=="58" set "TWO_STEP=1"

if %TWO_STEP%==1 (
    rem 5.7's Build.bat mangles the -CompilerVersion arg (14 .44.35207),
    rem so call the bundled dotnet + UBT.dll directly.
    if "%VER%"=="57" (
        echo   [A] Precompiling Game target with UBT direct %EXTRA% ...
        call "%UE_DIR%\Engine\Binaries\ThirdParty\DotNet\8.0.412\win-x64\dotnet.exe" ^
            "%UE_DIR%\Engine\Binaries\DotNET\UnrealBuildTool\UnrealBuildTool.dll" ^
            "UE%VER%_PSView" Win64 Development -project="%PROJ%" %EXTRA%
    ) else (
        echo   [A] Precompiling Game target with Build.bat %EXTRA% ...
        call "%BUILD%" "UE%VER%_PSView" Win64 Development -project="%PROJ%" %EXTRA%
    )
    if errorlevel 1 (
        echo.
        echo [FAIL] Win64 precompile failed!
        set /a FAILED+=1
        goto :eof
    )
    echo   [B] Cook/Stage/Pak/Archive via UAT, no compile ...
    echo.
    call "%UAT%" BuildCookRun ^
        -project="%PROJ%" ^
        -platform=Win64 ^
        -clientconfig=Development ^
        -cook -stage -pak -archive ^
        -archivedirectory="%ARCHIVE%" ^
        -nocompile -nocompileeditor ^
        -utf8output
) else (
    call "%UAT%" BuildCookRun ^
        -project="%PROJ%" ^
        -platform=Win64 ^
        -clientconfig=Development ^
        -build -cook -stage -pak -archive ^
        -archivedirectory="%ARCHIVE%" ^
        -utf8output ^
        %EXTRA%
)

if errorlevel 1 (
    echo.
    echo [FAIL] Win64 package failed!
    set /a FAILED+=1
    goto :eof
)

:: Rename Windows -> Windows%VER%
if exist "%ARCHIVE%\Windows%VER%" rd /s /q "%ARCHIVE%\Windows%VER%"
if exist "%ARCHIVE%\Windows" ren "%ARCHIVE%\Windows" "Windows%VER%"
set /a SUCCEED+=1
echo.
echo [OK] Win64 done: %ARCHIVE%\Windows%VER%
echo.
:: Create Windows%VER%.zip for upload
echo   [ZIP] Creating Windows%VER%.zip ...
if exist "%ARCHIVE%\Windows%VER%.zip" del /q "%ARCHIVE%\Windows%VER%.zip"
tar -a -c -f "%ARCHIVE%\Windows%VER%.zip" -C "%ARCHIVE%" "Windows%VER%"
echo.
echo [OK] Zip created: %ARCHIVE%\Windows%VER%.zip
echo.
:skip_win

:: ---------------- Linux ----------------
if %DO_LINUX%==0 goto :done
set /a STEP+=1
echo [%STEP%] Packaging Linux ...
echo.
if not exist "%LINUX_TOOLCHAIN%" (
    echo [ERROR] Toolchain not found: %LINUX_TOOLCHAIN%
    set /a FAILED+=1
    goto :eof
)

set "LINUX_MULTIARCH_ROOT=%LINUX_TOOLCHAIN%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "[System.Environment]::SetEnvironmentVariable('LINUX_MULTIARCH_ROOT', '%LINUX_TOOLCHAIN%', 'User')" >nul
echo   Toolchain: %TOOLCHAIN%
echo.

call "%UAT%" BuildCookRun ^
    -project="%PROJ%" ^
    -platform=Linux ^
    -clientconfig=Development ^
    -build -cook -stage -pak -archive ^
    -archivedirectory="%ARCHIVE%" ^
    -utf8output

if errorlevel 1 (
    echo.
    echo [FAIL] Linux package failed!
    set /a FAILED+=1
    goto :eof
)

:: Rename Linux -> Linux%VER%
if exist "%ARCHIVE%\Linux%VER%" rd /s /q "%ARCHIVE%\Linux%VER%"
if exist "%ARCHIVE%\Linux" ren "%ARCHIVE%\Linux" "Linux%VER%"
set /a SUCCEED+=1
echo.
echo [OK] Linux done: %ARCHIVE%\Linux%VER%
echo.
:: Create Linux%VER%.zip for upload
echo   [ZIP] Creating Linux%VER%.zip ...
if exist "%ARCHIVE%\Linux%VER%.zip" del /q "%ARCHIVE%\Linux%VER%.zip"
tar -a -c -f "%ARCHIVE%\Linux%VER%.zip" -C "%ARCHIVE%" "Linux%VER%"
echo.
echo [OK] Zip created: %ARCHIVE%\Linux%VER%.zip
echo.
:done

goto :eof

:summary
echo.
echo ============================================
if !FAILED! gtr 0 (
    echo   Done. Succeeded: !SUCCEED!, Failed: !FAILED!
) else (
    echo   Done. All !SUCCEED! packages succeeded.
)
echo ============================================
echo.
exit /b !FAILED!
