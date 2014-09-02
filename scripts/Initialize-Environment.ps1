Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition

. .\Utilities.ps1

$sitePhysicalPath = Resolve-FullPath -Path "$scriptPath\..\src\web"
Initialize-WebServer -siteName "Code Camp Server" `
                     -sitePhysicalPath $sitePhysicalPath `
                     -httpPort 1337 `
                     -httpsPort 1338

Write-Host ""
Write-Host "**********************************************************************" -foregroundcolor magenta
Write-Host ""
Write-Host " Setup complete, you can now access the site at:"
Write-Host ""
Write-Host " http://codecampserver.localtest.me:1337" -foregroundcolor green
Write-Host " https://codecampserver.localtest.me:1338" -foregroundcolor green
Write-Host ""
Write-Host " Modify your VS Web Settings to Servers -> External Host and Project Url -> https://codecampserver.localtest.me:1338"
Write-Host ""    
Write-Host " If you are getting a 'HTTP Error 403.14 - Forbidden' error when access those urls"
Write-Host " , make sure asp.net 4.5 has been registered in IIS by doing the following:"
Write-Host " Turn on 'IIS-ASPNET45' in 'Turn Windows Features On/Off' under 'Internet Information Services"
Write-Host " -> World Wide Web Services -> Application Development Features -> ASP.NET 4.5'."
Write-Host ""
Write-Host "**********************************************************************" -foregroundcolor magenta    