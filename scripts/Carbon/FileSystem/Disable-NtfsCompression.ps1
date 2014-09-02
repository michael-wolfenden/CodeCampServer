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

function Disable-NtfsCompression
{
    <#
    .SYNOPSIS
    Turns off NTFS compression on a file/directory.

    .DESCRIPTION
    When disabling compression for a directory, any compressed files/directories in that directory will remain compressed.  To decompress everything, use the `-Recurse` switch.  This could take awhile.

    Uses Windows' `compact.exe` command line utility to compress the file/directory.  To see the output from `compact.exe`, set the `Verbose` switch.

    .LINK
    Enable-NtfsCompression

    .LINK
    Test-NtfsCompression

    .EXAMPLE
    Disable-NtfsCompression -Path C:\Projects\Carbon

    Turns off NTFS compression on and decompresses the `C:\Projects\Carbon` directory, but not its sub-directories/files.  New files/directories will get compressed.

    .EXAMPLE
    Disable-NtfsCompression -Path C:\Projects\Carbon -Recurse

    Turns off NTFS compression on and decompresses the `C:\Projects\Carbon` directory and all its sub-directories/sub-files.

    .EXAMPLE
    Get-ChildItem * | Where-Object { $_.PsIsContainer } | Disable-NtfsCompression

    Demonstrates that you can pipe the path to compress into `Disable-NtfsCompression`.
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]
        [string[]]
        [Alias('FullName')]
        # The path where compression should be disabled.
        $Path,

        [Switch]
        # Disables compression on all sub-directories.
        $Recurse
    )

    begin
    {
        $compactPath = Join-Path $env:SystemRoot 'system32\compact.exe'
        if( -not (Test-Path -Path $compactPath -PathType Leaf) )
        {
            if( (Get-Command -Name 'compact.exe' -ErrorAction SilentlyContinue) )
            {
                $compactPath = 'compact.exe'
            }
            else
            {
                Write-Error ("Compact command '{0}' not found." -f $compactPath)
                return
            }
        }
    }

    process
    {
        if( -not (Test-Path -Path $Path) )
        {
            Write-Error -Message ('Path {0} not found.' -f $Path) -Category ObjectNotFound
            return
        }

        $recurseArg = ''
        $pathArg = $Path
        if( (Test-Path -Path $Path -PathType Container) )
        {
            if( $Recurse )
            {
                $recurseArg = ('/S:{0}' -f $Path)
                $pathArg = ''
            }
        }

        if( $PSCmdlet.ShouldProcess( $Path, 'disable NTFS compression' ) )
        {
            Write-Host ('Disabling NTFS compression on {0}.' -f $Path)
            & $compactPath /U $recurseArg $pathArg | Write-Verbose
            if( $LASTEXITCODE )
            {
                Write-Error ('{0} failed with exit code {1}' -f $compactPath,$LASTEXITCODE)
            }
        }
    }
}