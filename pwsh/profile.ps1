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
# GitHub Copilot CLI: opt-in routing to a local LM Studio server (BYOK)
#
# https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/use-byok-models
#
# By default, plain `copilot` keeps using GitHub-hosted models. Run `colo`,
# `colo9`, or `colo30` to launch Copilot CLI against a locally running LM
# Studio instance for the duration of that one invocation only. Each function
# saves and restores any pre-existing COPILOT_* env vars so they do not leak
# into the calling shell.
#
#     colo    -> qwen/qwen3.5-9b       (default; lighter, fast)
#     colo9   -> qwen/qwen3.5-9b       (explicit)
#     colo30  -> qwen/qwen3-coder-30b  (heavier, coder-tuned)
#
# Requires LM Studio's local server enabled at http://127.0.0.1:11234 with a
# tool-calling-capable model loaded at >=64k context (>=128k recommended).
#-----------------------------------------------------------------------------------------------------------------

function script:Invoke-CopilotLmStudio {
    param(
        [string]$Model,
        [bool]$Offline,
        [object[]]$ForwardArgs
    )

    $overrides = @{
        COPILOT_PROVIDER_TYPE     = 'openai'
        COPILOT_PROVIDER_BASE_URL = 'http://127.0.0.1:11234/v1'
        COPILOT_MODEL             = $Model
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
        & copilot @ForwardArgs
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

function global:colo {
    param([switch]$Offline)
    Invoke-CopilotLmStudio -Model 'qwen/qwen3.5-9b' -Offline $Offline -ForwardArgs $args
}

function global:colo9 {
    param([switch]$Offline)
    Invoke-CopilotLmStudio -Model 'qwen/qwen3.5-9b' -Offline $Offline -ForwardArgs $args
}

function global:colo30 {
    param([switch]$Offline)
    Invoke-CopilotLmStudio -Model 'qwen/qwen3-coder-30b' -Offline $Offline -ForwardArgs $args
}
