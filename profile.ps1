if (-not (Test-Path env:pwsh_devenv)) { $env:pwsh_devenv = "$HOME\source\repos\PowerShell-DevEnv\" }

$devEnvScriptPath = Join-Path $env:pwsh_devenv Set-DevelopmentEnvironment.ps1

if (Test-Path $devEnvScriptPath) {
  Write-Output "Running dev environment setup script"
  Write-Output ""
  . $devEnvScriptPath
} else { 
  Write-Warning "Unable to locate dev environment setup script @ $devEnvScriptPath" 
}

if((Get-Item $env:SystemRoot\System32).Fullname -eq $pwd.Path)
{
    set-location  ~ | out-null
}