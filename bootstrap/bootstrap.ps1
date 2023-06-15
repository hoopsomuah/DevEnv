<#
.SYNOPSIS
    Web Bootstrap script for a new machine.
.NOTES
    Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/hoopsomuah/DevEnv/master/bootstrap.ps1" | Invoke-Expression
#>
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

if (-not(Get-Command git.exe -ErrorAction SilentlyContinue))
{
    if(Confirm-Action "Git is not installed. Install Git?")
    {
        Write-Host "Installing Git"
        winget.exe install -e --id Git.Git    
    }
    else 
    {
        Write-Warning "Skipping Git installation. Git is required to clone the DevEnv repo"
        exit
    }
}

Write-Host "Cloning DevEnv repo to $env:pwsh_devenv"
git clone https://github.com/$repo.git $env:pwsh_devenv

Push-Location $env:pwsh_devenv
. .\bootstrap\Configure-DevBox.ps1

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