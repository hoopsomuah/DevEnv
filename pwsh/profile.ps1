if (-not (Test-Path env:pwsh_devenv)) { 
  $env:pwsh_devenv = "$HOME\src\DevEnv\" 
  Write-Warning "env:pwsh_devenv not set. Using default path $env:pwsh_devenv"
}

if (-not (Test-Path $env:pwsh_devenv))
{
  Write-Warning "DevEnv not found at $env:pwsh_devenv. Either clone the DevEnv Repo using the bootstrap script or set env:pwsh_devenv to the path of the DevEnv repo or copy a local version of the repo to this machine and run the bootstrap script."
  exit
}

#-----------------------------------------------------------------------------------------------------------------
# Drive Aliases
#
# This section creates PowerShell drives for some common directories
#
#-----------------------------------------------------------------------------------------------------------------

$driveAliases = @{}

$driveAliases['src'] = join-path $env:userprofile "src"
$driveAliases['repos'] = join-path $driveAliases['src'] "repos"
$driveAliases["oss"] = join-path $driveAliases['repos'] "oss"


$alternateDriveFunctionNames = @{}
$alternateDriveFunctionNames['variable'] = "var"
$alternateDriveFunctionNames['function'] = "fn"


# Create new PS Drives
foreach ($d in $driveAliases.GetEnumerator()) {
    if (-not (test-path $d.Value)) {
        Write-Host "Not creating $($d.Key): Local copy does not exist"
        continue
    }

    if (test-path "$($d.Key):") {
        Write-Host "Not creating $($d.Key): because the drive is already in use"
        continue
    }

    new-psdrive $d.Key FileSystem $d.Value -Scope Global | out-null

}

# Replace PS Drive Functions
foreach ($d in Get-PSDrive) {
    if (test-path "function:global:$($d.Name):") {
        remove-item -path "function:\$($d.Name):"
    }

    $functionName = $alternateDriveFunctionNames[$d.Name]
    if ($null -eq $functionName) { $functionName = "$($d.Name)" }

    $scriptBlock = "Set-Location $($d.Name):"
    new-item -path "function:global:$($functionName):" -value $scriptBlock | out-null
}

$ompPath = Join-Path $env:pwsh_devenv "ohmyposh\hoop.omp.json"
oh-my-posh init pwsh --config $ompPath | Invoke-Expression

$utilitiesPath = Join-Path $env:pwsh_devenv "pwsh\utilities.ps1"
. $utilitiesPath

Replace-PsDriveFunctions

#-----------------------------------------------------------------------------------------------------------------
# GitHub Copilot CLI: route to local Foundry Local server (BYOK)
#
# https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-byok-models
#
# Foundry Local is pinned to port 5273 via:
#     foundry service set --port 5273
#
# This block is idempotent (always sets to the same values) and is gated on
# `foundry.exe` being on PATH so the profile stays portable to machines
# without Foundry Local installed.
#-----------------------------------------------------------------------------------------------------------------

if (Get-Command foundry.exe -ErrorAction SilentlyContinue) {
    $env:COPILOT_PROVIDER_TYPE     = 'openai'
    $env:COPILOT_PROVIDER_BASE_URL = 'http://localhost:5273/v1'
    # Foundry Local requires the full model ID including the revision suffix
    # (e.g. ":4"). The bare alias is rejected by /v1/chat/completions with 400.
    # Bump this when Microsoft publishes a new revision (`foundry model list`).
    $env:COPILOT_MODEL             = 'qwen2.5-coder-14b-instruct-cuda-gpu:4'
}
