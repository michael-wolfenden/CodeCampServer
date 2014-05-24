@echo off

set packages_dir=%~dp0src\packages

if '%1'=='/?' goto help
if '%1'=='-help' goto help
if '%1'=='-h' goto help

powershell -NoProfile -ExecutionPolicy Bypass -Command "$psake_script_path = @(gci '%packages_dir%' -filter psake.ps1 -recurse)[0].FullName;& $psake_script_path build.ps1 %*; if ($psake.build_success -eq $false) { exit 1 } else { exit 0 }"
exit /B %errorlevel%

:help
powershell -NoProfile -ExecutionPolicy Bypass -Command "$psake_script_path = @(gci '%packages_dir%' -filter psake.ps1 -recurse)[0].FullName;& $psake_script_path -help"
