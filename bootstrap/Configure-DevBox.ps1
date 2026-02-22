
# check if we are running as admin and escalate if not.
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Error "Dev Box Configuration Cancelled. This script must be run as Administrator."
    exit
}

Set-ExecutionPolicy RemoteSigned -Force

$wingetArgs = ''
if ($VerbosePreference -ne 'SilentlyContinue') { $wingetArgs += ' --verbose' }

Write-Host "Installing Requirements..."

&winget.exe configure --enable
&winget.exe configure --accept-configuration-agreements --suppress-initial-details --disable-interactivity -f $PSScriptRoot\..\winget\min-dev.dsc.yaml $wingetArgs

# ---  Configure Powershell Profile ---
if (Test-Path $Profile.CurrentUserAllHosts)
{
    if(Confirm-Action "You have a Powershell Profile already located at `"$($Profile.CurrentUserAllHosts)`". Overwrite Existing Profile?")
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

# copy the contents of the bootstrap folder to the users powershell script folder
Copy-Item -Path "$PSScriptRoot\..\pwsh\profile.ps1" -Destination $Profile.CurrentUserAllHosts -Recurse -Force


