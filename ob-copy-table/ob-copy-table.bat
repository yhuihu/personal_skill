@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

REM ============================================================
REM  ob-copy-table.bat
REM  使用 obdumper + obloader 复制 OceanBase 表结构及数据
REM ============================================================

REM --- 参数解析 ---
set SOURCE_TABLE=%~1
set TARGET_TABLE=%~2
set HOST=%~3
set PORT=%~4
set DB_USER=%~5
set DB_PASS=%~6
set DATABASE=%~7

if "%SOURCE_TABLE%"=="" goto USAGE
if "%TARGET_TABLE%"=="" goto USAGE
if "%HOST%"==""     goto USAGE
if "%PORT%"==""     goto USAGE
if "%DB_USER%"==""  goto USAGE
if "%DB_PASS%"==""  goto USAGE
if "%DATABASE%"=="" goto USAGE

REM --- 工具路径配置 ---
REM 默认直接使用 obdumper/obloader 命令（需已加入 PATH 环境变量）。
REM 如果未加入 PATH，可在此修改变量指向实际路径，例如：
REM   set OBDUMPER=D:\tools\ob-loader-dumper\bin\windows\obdumper.bat
REM   set OBLOADER=D:\tools\ob-loader-dumper\bin\windows\obloader.bat
REM ob-loader-dumper 需要 hadoop.dll，如果报 NativeIO 错误，设置 HADOOP_BIN 指向 hadoop\bin 目录：
REM   set HADOOP_BIN=D:\tools\ob-loader-dumper\ext\windows\hadoop\bin
set SCRIPT_DIR=%~dp0
set OBDUMPER=obdumper
set OBLOADER=obloader
set HADOOP_BIN=

if not "%HADOOP_BIN%"=="" set PATH=%HADOOP_BIN%;%PATH%

REM --- 创建工作目录 ---
set WORK_DIR=%TEMP%\ob_copy_%SOURCE_TABLE%_%RANDOM%
mkdir "%WORK_DIR%\ddl" "%WORK_DIR%\data" 2>nul

echo ========================================
echo  复制表: %SOURCE_TABLE% -^> %TARGET_TABLE%
echo ========================================
echo  主机: %HOST%:%PORT%
echo  数据库: %DATABASE%
echo  工作目录: %WORK_DIR%
echo ========================================

REM --- Step 1: 导出 DDL ---
echo [1/4] 正在导出表结构 (DDL) ...
call "%OBDUMPER%" ^
    -h %HOST% -P %PORT% -u %DB_USER% -p %DB_PASS% ^
    -D %DATABASE% --ddl --table "%SOURCE_TABLE%" -f "%WORK_DIR%\ddl"
if %ERRORLEVEL% neq 0 (
    echo [错误] DDL 导出失败
    exit /b %ERRORLEVEL%
)

REM --- Step 2: 导出 CSV 数据 ---
echo [2/4] 正在导出表数据 (CSV) ...
call "%OBDUMPER%" ^
    -h %HOST% -P %PORT% -u %DB_USER% -p %DB_PASS% ^
    -D %DATABASE% --csv --table "%SOURCE_TABLE%" -f "%WORK_DIR%\data"
if %ERRORLEVEL% neq 0 (
    echo [错误] 数据导出失败
    exit /b %ERRORLEVEL%
)

REM --- Step 3: 修改 DDL 表名 ---
echo [3/4] 正在修改 DDL 表名 ...
for %%f in ("%WORK_DIR%\ddl\*.sql") do (
    powershell -ExecutionPolicy Bypass -File "%SCRIPT_DIR%replace_table_name.ps1" ^
        -FilePath "%%f" -SourceName "%SOURCE_TABLE%" -TargetName "%TARGET_TABLE%"
)

REM --- 合并数据文件到 DDL 目录（obloader 统一导入）---
echo [3/4] 合并数据文件到 DDL 目录 ...
xcopy "%WORK_DIR%\data\*" "%WORK_DIR%\ddl\" /E /Y >nul

REM --- Step 4: 导入 DDL + 数据 ---
echo [4/4] 正在导入到目标表 %TARGET_TABLE% ...
call "%OBLOADER%" ^
    -h %HOST% -P %PORT% -u %DB_USER% -p %DB_PASS% ^
    -D %DATABASE% --ddl --csv -f "%WORK_DIR%\ddl"
if %ERRORLEVEL% neq 0 (
    echo [错误] 数据导入失败
    exit /b %ERRORLEVEL%
)

REM --- 清理 ---
echo [完成] 清理临时文件 ...
rmdir /s /q "%WORK_DIR%" 2>nul

echo ========================================
echo  ✅ 复制完成: %SOURCE_TABLE% -^> %TARGET_TABLE%
echo ========================================
exit /b 0

:USAGE
echo 用法: %~nx0 ^<原表名^> ^<目标表名^> ^<主机^> ^<端口^> ^<用户名^> ^<密码^> ^<数据库^>
echo.
echo 示例:
echo   %~nx0 mytable mytable_copy 127.0.0.1 2881 root@test mypass test
echo.
echo 全部 7 个参数均为必填，无默认值。
exit /b 1
