# Copyright 2012 Aaron Jensen
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

function Get-Certificate
{
    <#
    .SYNOPSIS
    Gets a certificate from a file on the file system or from a Windows certificate store by thumbprint or friendly name.

    .DESCRIPTION
    Certificates can be files or they can be in a Windows certificate store.  This function returns an `X509Certificate2` object for a script that's a file on the file system or a cert stored in Microsoft's certificate store.  You can get a certificate from a certificate store with its unique thumbprint or its friendly name.  Friendly names are *not* required to be unique, so you may get multiple certificates when using that search method.
    
    .OUTPUTS
    System.Security.Cryptography.x509Certificates.X509Certificate2. The X509Certificate2 certificates that were found, or `$null`.

    .EXAMPLE
    Get-Certificate -Path C:\Certificates\certificate.cer -Password MySuperSecurePassword
    
    Gets an X509Certificate2 object representing the certificate.cer file.
    
    .EXAMPLE
    Get-Certificate -Thumbprint a909502dd82ae41433e6f83886b00d4277a32a7b -StoreName My -StoreLocation LocalMachine
    
    Gets an X509Certificate2 object for the certificate in the Personal store with a specific thumbprint under the Local Machine.
    
    .EXAMPLE
    Get-Certificate -FriendlyName 'Development Certificate' -StoreLocation CurrentUser -StoreName TrustedPeople
    
    Gets the X509Certificate2 whose friendly name is Development Certificate from the Current User's Trusted People certificate store.
    
    .EXAMPLE
    Get-Certificate -Thumbprint a909502dd82ae41433e6f83886b00d4277a32a7b -CustomStoreName 'SharePoint' -StoreLocation LocalMachine

    Demonstrates how to get a certificate from a custom store, i.e. one that is not part of the standard `StoreName` enumeration.
    #>
    [CmdletBinding(DefaultParameterSetName='ByFriendlyName')]
    param(
        [Parameter(Mandatory=$true,ParameterSetName='ByPath')]
        [string]
        # The path to the certificate.
        $Path,
        
        [Parameter(ParameterSetName='ByPath')]
        # The password to the certificate.  Can be plaintext or a [SecureString](http://msdn.microsoft.com/en-us/library/system.securestring.aspx).
        $Password,
        
        [Parameter(Mandatory=$true,ParameterSetName='ByThumbprint')]
        [Parameter(Mandatory=$true,ParameterSetName='ByThumbprintCustomStoreName')]
        [string]
        # The certificate's thumbprint.
        $Thumbprint,
        
        [Parameter(Mandatory=$true,ParameterSetName='ByFriendlyName')]
        [Parameter(Mandatory=$true,ParameterSetName='ByFriendlyNameCustomStoreName')]
        [string]
        # The friendly name of the certificate.
        $FriendlyName,
        
        [Parameter(Mandatory=$true,ParameterSetName='ByFriendlyName')]
        [Parameter(Mandatory=$true,ParameterSetName='ByFriendlyNameCustomStoreName')]
        [Parameter(Mandatory=$true,ParameterSetName='ByThumbprint')]
        [Parameter(Mandatory=$true,ParameterSetName='ByThumbprintCustomStoreName')]
        [Security.Cryptography.X509Certificates.StoreLocation]
        # The location of the certificate's store.
        $StoreLocation,
        
        [Parameter(Mandatory=$true,ParameterSetName='ByFriendlyName')]
        [Parameter(Mandatory=$true,ParameterSetName='ByThumbprint')]
        [Security.Cryptography.X509Certificates.StoreName]
        # The name of the certificate's store.
        $StoreName,

        [Parameter(Mandatory=$true,ParameterSetName='ByFriendlyNameCustomStoreName')]
        [Parameter(Mandatory=$true,ParameterSetName='ByThumbprintCustomStoreName')]
        [string]
        # The name of the non-standard, custom store.
        $CustomStoreName
    )

    Set-StrictMode -Version 'Latest'

    if( $PSCmdlet.ParameterSetName -eq 'ByPath' )
    {
        $Path = ConvertTo-FullPath -Path $Path
    
        try
        {
            return New-Object Security.Cryptography.X509Certificates.X509Certificate2 $Path,$Password
        }
        catch
        {
            Write-Error ('Failed to create X509Certificate2 object from certificate at ''{0}'': {1}' -f $Path,$_)
        }
    }
    else
    {
        $storeLocationPath = '*'
        if( $StoreLocation )
        {
            $storeLocationPath = $StoreLocation
        }
        
        $storeNamePath = '*'
        $storeNamePath = $StoreName
        if( $PSCmdlet.ParameterSetName -like '*CustomStoreName' )
        {
            $storeNamePath = $CustomStoreName
        }
        else
        {
            $storeNamePath = $StoreName
        }
        
        if( $pscmdlet.ParameterSetName -like 'ByThumbprint*' )
        {
            $certPath = 'cert:\{0}\{1}\{2}' -f $storeLocationPath,$storeNamePath,$Thumbprint
            if( (Test-Path -Path $certPath) )
            {
                return Get-ChildItem -Path $certPath
            }
            return
        }
        elseif( $PSCmdlet.ParameterSetName -like 'ByFriendlyName*' )
        {
            return Get-ChildItem cert:\$storeLocationPath\$storeNamePath\* | Where-Object { $_.FriendlyName -eq $FriendlyName }
        }
        Write-Error "Unknown parameter set '$($pscmdlet.ParameterSetName)'."
    }
}
