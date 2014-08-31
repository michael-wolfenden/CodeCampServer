Import-Module "./utilities.psm1"

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path;

$codeCampServerPhysicalPath = Convert-Path "$scriptRoot\..\src\web"
Add-SiteToIIS "Code Camp Server" $codeCampServerPhysicalPath
