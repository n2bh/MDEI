@echo off
setlocal EnableDelayedExpansion

:: Database
set db_user=
set db_password=
set db_database=

:: Mysql
set mysqldump=mysqldump.exe
set mysql=mysql.exe

set args=true
if "%1"=="" set args=false
if "%2"=="" set args=false

if "!args!"=="false" (

echo import / export [products] OR backup [filename]

) else (

:: Import
set io_dir=%~dp0
set io_type=%1
set io_import=%2
set io_files=!io_dir!files\
set io_backups=!io_dir!backups\

if "!io_type!"=="import" (

:: Backup
set bu_datetime=!date:~6,4!!date:~3,2!!date:~0,2!!time:~0,2!!time:~3,2!!time:~6,2!
set bu_datetime=!bu_datetime: =0!
set bu_tables=
FOR /f "tokens=2 delims=:" %%a in ('findstr /r /c:"^# backup:.*$" "!io_files!!io_type!_!io_import!.sql"') DO IF NOT %%a=="" (set bu_tables=!bu_tables!%%a )

:: Execute Backup
!mysqldump! -u "!db_user!" -p"!db_password!" "!db_database!" ""!bu_tables:~0,-1!"" > "!io_backups!!io_import!_!bu_datetime!.sql"

echo Backup for !io_import! was completed

:: Execute Import
!mysql! -u "!db_user!" -p"!db_password!" "!db_database!" < "!io_files!!io_type!_!io_import!.sql"

echo Data for !io_import! was imported

)

if "!io_type!"=="backup" (

:: Execute backup
!mysql! -u "!db_user!" -p"!db_password!" "!db_database!" < "!io_backups!!io_import!"

echo Backup was restored

)

)
