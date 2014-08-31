function Test() {
    $makeCertPath = Get-MarkCertPath
    $domain  ="codecampserver"
   & $makeCertPath -r -pe -n "CN=$domain.localtest.me" -b `"$([DateTime]::Now.ToString("MM\/dd\/yyy"))`" -e `"$([DateTime]::Now.AddYears(10).ToString("MM\/dd\/yyy"))`" -eku 1.3.6.1.5.5.7.3.1 -ss my -sr localMachine -sky exchange -sp "Microsoft RSA SChannel Cryptographic Provider" -sy 12
       
}

function Add-SiteToIIS($siteName, $sitePhysicalPath)
{
    if(!(Test-IsUserAdministrator)) {
        throw "This script must be run as an admin."
    }
    Write-Host "User is administrator: true"

    if(!(Test-IISInstalled)) {
        throw "It looks like you do not have IIS Installed."
    }
    Write-Host "IIS installed: true"

    if(!(Test-Path $sitePhysicalPath)) {
        throw "Could not find site at $sitePhysicalPath."
    }
    $sitePhysicalPath = Convert-Path $sitePhysicalPath
    Write-Host "SitePhysicalPath: $sitePhysicalPath"

    $makeCertPath = Get-MarkCertPath
    if(!(Test-Path $makeCertPath)) {
        throw "Could not find makecert.exe in $makeCertPath!"
    }
    Write-Host "MakeCertPath: $makeCertPath"

    $appCmdPath = "c:\windows\system32\inetsrv\AppCmd.exe"
    if(!(Test-Path $AppCmdPath)) {
        throw "Could not find AppCmd.exe in $AppCmdPath!, are you sure IIS is installed?"
    }
    Write-Host "AppCmdPath: $appCmdPath"

    $domain = $siteName.ToLower() -replace " ",""
    $appPoolName = $domain + "_apppool"
    $siteFullName = "$siteName ($domain.localtest.me)"

    $sites = @(&$appCmdPath list site $siteFullName)
    if ($sites.Length -gt 0) {
        Write-Warning "Site '$siteFullName' already exists. Deleting and recreating."
        &$AppCmdPath delete site "$siteFullName"
    }

    Write-Information "Creating Integrated AppPool $appPoolName running as NetworkService" 
    &$appCmdPath add apppool /name:$appPoolName /managedRuntimeVersion:v4.0 /managedPipelineMode:Integrated
    &$appCmdPath set config /section:applicationPools "/[name='$appPoolName'].processModel.identityType:NetworkService"

    Write-Information "Creating site $siteFullName" 
    &$appCmdPath add site /name:"$siteFullName" /physicalPath:$sitePhysicalPath /bindings:"http://$domain.localtest.me:80,https://$domain.localtest.me:443" 
    &$appCmdPath set app "$siteFullName/" /applicationPool:"$appPoolName"

    # Change anonymous identity to auth as app-pool identity instead of IUSR_...
    &$AppCmdPath set config /section:anonymousAuthentication /username:"" --password
     
    # Give Network Service persmission to read the site files
    & icacls "$sitePhysicalPath" /inheritance:e /T /grant """NETWORK SERVICE:(OI)(CI)F"""

    $cert = New-Certificate $makeCertPath $domain
    Write-Host "Using SSL Certificate: $($cert.Thumbprint))"

    # Set the Certificate
    Invoke-Netsh http add sslcert hostnameport="$domain.localtest.me:443" certhash="$($cert.Thumbprint)" certstorename=My appid="{$([Guid]::NewGuid().ToString())}"

    Write-Host ""
    Write-Host "**********************************************************************" -foregroundcolor yellow
    Write-Host ""
    Write-Host " Setup complete, you can now access the site at:"
    Write-Host ""
    Write-Host " http://$domain.localtest.me" -foregroundcolor green
    Write-Host " https://$domain.localtest.me" -foregroundcolor green
    Write-Host ""
    Write-Host " If you are getting a 'HTTP Error 403.14 - Forbidden' error when access those urls"
    Write-Host " , make sure asp.net 4.5 has been registered in IIS by doing the following:"
    Write-Host " Turn on 'IIS-ASPNET45' in 'Turn Windows Features On/Off' under 'Internet Information Services"
    Write-Host " -> World Wide Web Services -> Application Development Features -> ASP.NET 4.5'."
    Write-Host ""
    Write-Host "**********************************************************************" -foregroundcolor yellow    

    return 
}

function Test-IsUserAdministrator() 
{
  $user = ([Security.Principal.WindowsPrincipal]([System.Security.Principal.WindowsIdentity]::GetCurrent()))
  return $user.IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")
}

function Test-IISInstalled() {
    $installed = $False
    $iisServiceName = "W3SVC"

    if ( Get-Service "$iisServiceName*" -Include $iisServiceName) {
        $installed = $True
    }
    
    return $installed
}


function Get-MarkCertPath()
{
   $SDKVersion = dir 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Microsoft SDKs\Windows' | 
       where { $_.PSChildName -match "v(?<ver>\d+\.\d+)" } | 
       foreach { New-Object System.Version $($matches["ver"]) } |
       sort -desc |
       select -first 1

   if(!$SDKVersion) {
       throw "Could not find Windows SDK. Please install the Windows SDK before running this script, or use -MakeCertPath to specify the path to makecert.exe"
   }

   $SDKRegKey = (Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Microsoft SDKs\Windows\v$SDKVersion")
   $WinSDKDir = $SDKRegKey.InstallationFolder
   
   $xArch = "x86"
   if($env:PROCESSOR_ARCHITECTURE -eq "AMD64") {
       $xArch = "x64"
   }

   return Join-Path $WinSDKDir "bin\$xArch\makecert.exe"
}

function Write-Warning([string] $message)
{
    Write-Host $message -foregroundcolor yellow
}

function Write-Information([string] $message)
{
    Write-Host $message -foregroundcolor magenta
}

function New-Certificate($makeCertPath, $domain)
{
    # Check for a cert
    $cert = @(dir -l "Cert:\LocalMachine\My" | where {$_.Subject -eq "CN=$domain.localtest.me"})

    if($cert.Length -eq 0) {
        Write-Information "Generating a Self-Signed SSL Certificate for $domain.localtest.me"
        & $makeCertPath -r -pe -n "CN=$domain.localtest.me" -b `"$([DateTime]::Now.ToString("MM\/dd\/yyy"))`" -e `"$([DateTime]::Now.AddYears(10).ToString("MM\/dd\/yyy"))`" -eku 1.3.6.1.5.5.7.3.1 -ss my -sr localMachine -sky exchange -sp "Microsoft RSA SChannel Cryptographic Provider" -sy 12
        $cert = @(dir -l "Cert:\LocalMachine\My" | where {$_.Subject -eq "CN=$domain.localtest.me"})
    }

    if($cert.Length -eq 0) {
        throw "Failed to create an SSL Certificate"
    }

    return $cert
}

function Invoke-Netsh() {
    $argStr = $([String]::Join(" ", $args))
    Write-Verbose "netsh $argStr"
    $result = netsh @args
    $parsed = [Regex]::Match($result, ".*Error: (\d+).*")
    if($parsed.Success) {
        $err = $parsed.Groups[1].Value
        if($err -ne "183") {
            throw $result
        }
    } else {
        Write-Host $result
    }
}