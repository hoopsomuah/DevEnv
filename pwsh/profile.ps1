if (-not (Test-Path env:pwsh_devenv)) { 
  $env:pwsh_devenv = "$HOME\src\DevEnv\" 
  Write-Warning "env:pwsh_devenv not set. Using default path $env:pwsh_devenv"
}

if (-not (Test-Path $env:pwsh_devenv))
{
  Write-Warning "DevEnv not found at $env:pwsh_devenv. Either clone the DevEnv Repo using the bootstrap script or set env:pwsh_devenv to the path of the DevEnv repo or copy a local version of the repo to this machine and run the bootstrap script."
  exit
}

$ompPath = Join-Path $env:pwsh_devenv "ohmyposh\hoop.omp.json"
oh-my-posh init pwsh --config $ompPath | Invoke-Expression

$utilitiesPath = Join-Path $env:pwsh_devenv "pwsh\utilities.ps1"
. $utilitiesPath

Replace-PsDriveFunctions