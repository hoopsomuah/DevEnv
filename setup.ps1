<#
.SYNOPSIS
    Setup script for a new machine
.DESCRIPTION
    This script will install all the apps and tools I use on a new machine.
    It will also configure the machine to my preferences.
.PARAMETER reLaunched
    This parameter is used to indicate that the script has been relaunched in elevated mode.
.NOTES
    Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/hoopsomuah/DevEnv/master/setup.ps1" | Invoke-Expression
#>
[CmdletBinding()]
param(
    [switch]$reLaunched,
    [string]$repo = "hoopsomuah/DevEnv/master" 
)


if ($reLaunched) {
    Write-Host "Relaunched in elevated mode..."
}
if ($repoBase) {
    Write-Host "Using repo base: $repoBase"
}

switch ($VerbosePreference) {
    'SilentlyContinue' { Write-Host "Normal Mode" }
    'Continue' { Write-Host "Diagnostic Mode" }
    'Stop' { Write-Host "Full Diagnostic Mode" }
}

function Confirm-Action {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    do {
        $response = Read-Host "$Message (Y/N)"
    } while ($response -notmatch "^[yn]$")

    return $response -eq "y"
}

try {

    # check if we are running as admin
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        if(Confirm-Action "This script must be run as Administrator.  Restart in elevated mode?")
        {
            $pwshArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$PSCommandPath", "-reLaunched") + $args
            Start-Process -FilePath pwsh.exe -ArgumentList $pwshArgs -Verb RunAs -Wait
        }
        exit
    }

    if (!(Get-Module posh-git -ListAvailable)) {
        Install-Module posh-git -Scope CurrentUser -Force 
    }

    if (!(Get-Module PSReadLine -ListAvailable)) {
        Install-Module -Name PSReadLine -AllowPrerelease -Scope CurrentUser -Force
    }

    $wingetArgs = switch ($VerbosePreference) {
        'SilentlyContinue' { '--disable-interactivity' }
        'Continue' { '--verbose' }
        'Stop' { '--verbose' }
        default { '--verbose' }
    }

    &winget.exe configure -f $PSScriptRoot\min-dev.dsc.yaml $wingetArgs

    if (Confirm-Action "Install all dev apps?") {
        &winget.exe configure -f $PSScriptRoot\dev-plus.dsc.yaml $wingetArgs
    }

    if ((Test-Path $Profile.CurrentUserAllHosts) -and -not(Confirm-Action "You have a Powershell Profile already located at "$($Profile.CurrentUserAllHosts)". Overwrite Existing Profile?"))
    {
        exit
    }

    #Check Whether we are in the git repo and not running this script from a download.
    if($repoBase)
    {
        $uri = "https://raw.githubusercontent.com/$repoBranch/bootstrap/profile.ps1"
        Invoke-WebRequest -Uri $uri -OutFile $Profile.CurrentUserAllHosts
    }
    if((git rev-parse --is-inside-work-tree) -and (Test-Path "$PSScriptRoot\bootstrap\profile.ps1"))
    {
        # copy the contents of the bootstrap folder to the users powershell script folder
        Copy-Item -Path "$PSScriptRoot\bootstrap\profile.ps1" -Destination $Profile.CurrentUserAllHosts -Recurse -Force
    } else {
        Write-Host "Not in a git repo and no base url specificed. Skipping profile setup."
        exit
    }

}
finally {
    if ($reLaunched) {
        Read-Host "Setup Complete. Press any key to continue..."
    }
}
