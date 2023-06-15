<#
.SYNOPSIS
    Web Bootstrap script for a new machine.
.NOTES
    Invoke-WebRequest -UseBasicParsing "https://raw.githubusercontent.com/hoopsomuah/DevEnv/master/bootstrap.ps1" | Invoke-Expression
#>
$repo = "hoopsomuah/DevEnv"

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

        #refresh the path
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    else 
    {
        Write-Warning "Skipping Git installation. Git is required to clone the DevEnv repo"
        exit
    }
}
$repoUrl = "https://github.com/$repo.git"
Write-Host "Cloning $repoUrl"
git.exe clone $repoUrl $env:pwsh_devenv

Push-Location $env:pwsh_devenv
Get-Content .\bootstrap\Configure-DevBox.ps1 | Invoke-Expression

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