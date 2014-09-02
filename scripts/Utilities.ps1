. .\Carbon\Import-Carbon.ps1

Function Initialize-WebServer
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True)]
        [string]$siteName,
        
        [Parameter(Mandatory=$True)]
        [string]$sitePhysicalPath,

        [Parameter(Mandatory=$True)]
        [int]$httpPort,
        
        [Parameter(Mandatory=$True)]
        [int]$httpsPort
    )

    if (!(Test-AdminPrivilege)) 
    {
        throw "This script must be run as an admin."
    }

    if (!(Test-Service -Name "W3SVC")) 
    {
        throw "Could not find the 'W3SVC' service. Is IIS installed?"
    }

    if (!(Test-Path $sitePhysicalPath)) 
    {
        throw "Could not find path '$sitePhysicalPath'"
    }    

    $domain = $siteName.ToLower() -replace " ",""
    $appPoolName = $domain + "_apppool"
    $fullDomainName = "$domain.localtest.me"
    $siteFullName = "$siteName ($fullDomainName)"

    $personalCert = Get-Certificate -FriendlyName $fullDomainName `
                                    -StoreLocation LocalMachine `
                                    -StoreName My

    if (!($personalCert -eq $null)) {
        Write-Host "Found certificate for $fullDomainName.pfx in Local Computer\Personal .. deleting" -foregroundcolor yellow

        Uninstall-Certificate -Certificate $personalCert `
                              -StoreLocation LocalMachine `
                              -StoreName My
    }

    $rootCert = Get-Certificate -FriendlyName $fullDomainName `
                                -StoreLocation LocalMachine `
                                -StoreName AuthRoot

    if (!($rootCert -eq $null)) {
        Write-Host "Found certificate for $fullDomainName.pfx in Local Computer\Trusted Root Certification Authorities .. deleting" -foregroundcolor yellow

        Uninstall-Certificate -Certificate $personalCert `
                              -StoreLocation LocalMachine `
                              -StoreName AuthRoot
    }

    Write-Host "Creating $fullDomainName.pfx for domain $fullDomainName" -foregroundcolor green
    New-SelfsignedCertificateEx -Subject "CN=$fullDomainName" `
                                -EKU "Server Authentication" `
                                -KeyUsage "DigitalSignature, KeyEncipherment, DataEncipherment" `
                                -FriendlyName $fullDomainName  `
                                -NotAfter $([datetime]::now.AddYears(5)) `
                                -Path "$fullDomainName.pfx" `
                                -Password (ConvertTo-SecureString "password" -AsPlainText -Force) `
                                -Exportable `

    Write-Host "Importing $fullDomainName.pfx into Local Computer\Personal certifcate store" -foregroundcolor green
    $cert = Install-Certificate -Path "$fullDomainName.pfx" `
                                -StoreLocation LocalMachine `
                                -StoreName My `
                                -Exportable `
                                -Password password

    Write-Host "Importing $fullDomainName.pfx into Local Computer\Trusted Root Certification Authorities certifcate store" -foregroundcolor green
    $cert = Install-Certificate -Path "$fullDomainName.pfx" `
                                -StoreLocation LocalMachine `
                                -StoreName AuthRoot `
                                -Exportable `
                                -Password password        

    Remove-Item "$fullDomainName.pfx"

    Write-Host "Setting SSL binding for thumbprint $($cert.Thumbprint) for port $httpsPort" -foregroundcolor green
    Set-SslCertificateBinding -ApplicationID ([Guid]::NewGuid()) `
                              -Thumbprint $($cert.Thumbprint) `
                              -Port $httpsPort           

    Write-Host "Creating application pool $appPoolName running as NetworkService" -foregroundcolor green
    Install-IisAppPool -Name $appPoolName `
                       -ServiceAccount NetworkService

    $httpBinding = "http://$fullDomainName" + ":" + $httpPort
    $httpsBinding = "https://$fullDomainName" + ":" + $httpsPort

    Write-Host "Creating site $siteFullName" -foregroundcolor green
    Install-IisWebsite -Path $sitePhysicalPath `
                       -Name $siteFullName `
                       -Bindings ($httpBinding, $httpsBinding) `
                       -AppPoolName $appPoolName   
}