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
# GitHub Copilot CLI: opt-in routing to local Foundry Local server (BYOK)
#
# https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-byok-models
#
# By default, plain `copilot` keeps using GitHub-hosted models. Run `colo` to
# launch Copilot CLI against a locally running Foundry Local instance for the
# duration of that one invocation only. The function saves and restores any
# pre-existing COPILOT_* env vars so it does not leak into the calling shell.
#
# Foundry Local must be pinned to port 5273 once per machine:
#     foundry service set --port 5273
#-----------------------------------------------------------------------------------------------------------------

function global:colo {
    [CmdletBinding()]
    param(
        [switch]$Offline,
        [Parameter(ValueFromRemainingArguments = $true)]
        [object[]]$CopilotArgs
    )

    if (-not (Get-Command foundry.exe -ErrorAction SilentlyContinue)) {
        Write-Error "Foundry Local is not installed (foundry.exe not on PATH). Install with: winget install Microsoft.FoundryLocal"
        return
    }

    # Bump the model ID suffix when Microsoft publishes a new revision
    # (`foundry model list` / GET http://localhost:5273/v1/models).
    $overrides = @{
        COPILOT_PROVIDER_TYPE     = 'openai'
        COPILOT_PROVIDER_BASE_URL = 'http://localhost:5273/v1'
        COPILOT_MODEL             = 'qwen2.5-coder-14b-instruct-cuda-gpu:4'
        COPILOT_OFFLINE           = if ($Offline) { 'true' } else { $null }
    }

    $saved = @{}
    foreach ($name in $overrides.Keys) {
        $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        if ($null -eq $overrides[$name]) {
            Remove-Item "Env:$name" -ErrorAction SilentlyContinue
        } else {
            Set-Item "Env:$name" $overrides[$name]
        }
    }

    try {
        & copilot @CopilotArgs
    } finally {
        foreach ($kv in $saved.GetEnumerator()) {
            if ([string]::IsNullOrEmpty($kv.Value)) {
                Remove-Item "Env:$($kv.Key)" -ErrorAction SilentlyContinue
            } else {
                Set-Item "Env:$($kv.Key)" $kv.Value
            }
        }
    }
}
