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

Write-Host "Cloning DevEnv repo to $env:pwsh_devenv"
git clone https://github.com/$repo.git $env:pwsh_devenv

Push-Location $env:pwsh_devenv
. .\bootstrap\Configure-DevBox.ps1