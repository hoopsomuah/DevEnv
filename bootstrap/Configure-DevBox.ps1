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

# validate that we're running in a git repo and not as a downloaded script
if(-not (git rev-parse --is-inside-work-tree))
{
    # if we're not in a git repo, ask the user and then clone the repo
    if(Confirm-Action "This script is not running within a git repo.  Clone repo to $env:pwsh_devenv? If not, The Powershell Profile configuration will be skipped")
    {
        if (Test-Path env:pwsh_devenv) { 
            $defaultPath = $env:pwsh_devenv
        } else {
            $defaultPath = "$HOME\src\DevEnv\"
        }
        #ask the user to provide a path to clone the repo. If they don't, use the default
        $userPath = Read-Host -Prompt "Enter a path to clone the DevEnv repo to (default: $defaultPath)"
        if (-not $userPath) {
            $env:pwsh_devenv = $defaultPath
        } else {
            $env:pwsh_devenv = $userPath
        }        

        git clone https://github.com/$repo.git $env:pwsh_devenv
        Push-Location $env:pwsh_devenv
    }
    else 
    {
        Write-Warning "Skipping Powershell Profile configuration. Not cloning repo"
        exit
    }
}

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

if((git rev-parse --is-inside-work-tree) -and (Test-Path "$PSScriptRoot\bootstrap\profile.ps1"))
{
    # copy the contents of the bootstrap folder to the users powershell script folder
    Copy-Item -Path "$PSScriptRoot\bootstrap\profile.ps1" -Destination $Profile.CurrentUserAllHosts -Recurse -Force
}

#----------------------------------------------------------
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