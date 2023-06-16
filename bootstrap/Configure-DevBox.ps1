[CmdletBinding()]

# check if we are running as admin and escalate if not.
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    if(Confirm-Action "This script must be run as Administrator.  Restart in elevated mode?")
    {
        $pwshArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$PSCommandPath") + $args
        Start-Process -FilePath pwsh.exe -ArgumentList $pwshArgs -Verb RunAs -Wait
        if ($LASTEXITCODE -ne 0)
        {
            Write-Host "Elevated Process exited with code $LASTEXITCODE"
        }
    } else {
        Write-Warning "Dev Box Configuration Cancelled"
    }
    exit
}

Set-ExecutionPolicy RemoteSigned -Force

if (!(Get-Module posh-git -ListAvailable)) { Install-Module posh-git -Scope CurrentUser -Force }
if (!(Get-Module PSReadLine -ListAvailable)) { Install-Module -Name PSReadLine -AllowPrerelease -Scope CurrentUser -Force }

$wingetArgs = switch ($VerbosePreference) {
    'SilentlyContinue' { '--disable-interactivity' }
    'Continue' { '--verbose' }
    'Stop' { '--verbose' }
    default { '--verbose' }
}

&winget.exe configure -f $PSScriptRoot\min-dev.dsc.yaml $wingetArgs

if (Confirm-Action "Install all dev apps?")
{ 
    &winget.exe configure -f $PSScriptRoot\dev-plus.dsc.yaml $wingetArgs
}

# ---  Configure Powershell Profile ---
if (Test-Path $Profile.CurrentUserAllHosts)
{
    if(Confirm-Action "You have a Powershell Profile already located at "$($Profile.CurrentUserAllHosts)". Overwrite Existing Profile?")
    {
        $guid = New-Guid
        $backupFile = "$($Profile.CurrentUserAllHosts).$guid.bak"
        Write-Host "Backing up existing profile to $backupFile"
        Rename-Item $Profile.CurrentUserAllHosts $backupFile -Force
    } else {
        Write-Warning "Skipping Powershell Profile configuration, existing profile not overwritten"    
        exit
    }
}

if(Test-Path "$PSScriptRoot\bootstrap\profile.ps1")
{
    # copy the contents of the bootstrap folder to the users powershell script folder
    Copy-Item -Path "$PSScriptRoot\bootstrap\profile.ps1" -Destination $Profile.CurrentUserAllHosts -Recurse -Force
}

