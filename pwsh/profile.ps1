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
# Copilot CLI launchers
#
#   c    : launch copilot here
#   cy   : launch copilot --yolo
#   cr   : launch copilot --resume
#   cyr  : launch copilot --resume --yolo
#
# If the first argument is an existing directory, copilot is launched in that
# directory; otherwise all arguments are forwarded to copilot.
#-----------------------------------------------------------------------------------------------------------------
function global:Invoke-CopilotHere {
    [CmdletBinding()]
    param(
        [string[]]$Flags = @(),
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$AllArgs
    )

    $path = $null
    $passthrough = @()
    if ($AllArgs -and $AllArgs.Count -gt 0) {
        $first = $AllArgs[0]
        if ($first -and -not $first.StartsWith('-') -and (Test-Path -LiteralPath $first -PathType Container)) {
            $path = $first
            if ($AllArgs.Count -gt 1) { $passthrough = $AllArgs[1..($AllArgs.Count - 1)] }
        } else {
            $passthrough = $AllArgs
        }
    }

    $argv = @('copilot') + $Flags + $passthrough

    if ($path) {
        Push-Location -LiteralPath $path
        try   { agency @argv }
        finally { Pop-Location }
    } else {
        agency @argv
    }
}

function global:c   { Invoke-CopilotHere @args }
function global:cy  { Invoke-CopilotHere -Flags '--yolo'                @args }
function global:cr  { Invoke-CopilotHere -Flags '--resume'              @args }
function global:cyr { Invoke-CopilotHere -Flags @('--resume','--yolo')  @args }

#-----------------------------------------------------------------------------------------------------------------
# DevEnv update checker
#
# Async, throttled, network-aware fetch of the DevEnv repo. Notifies the user
# at next prompt-time if origin has commits the local clone is missing.
#-----------------------------------------------------------------------------------------------------------------
function global:Start-DevEnvUpdateCheck {
    if (-not $env:pwsh_devenv) { return }
    $repo = $env:pwsh_devenv.TrimEnd('\')
    if (-not (Test-Path (Join-Path $repo '.git'))) { return }

    $stateDir  = Join-Path $env:LOCALAPPDATA 'DevEnv'
    $stateFile = Join-Path $stateDir 'last-update-check'
    if (-not (Test-Path $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
    if (Test-Path $stateFile) {
        $last = (Get-Item $stateFile).LastWriteTime
        if ((Get-Date) - $last -lt (New-TimeSpan -Hours 6)) { return }
    }

    if (-not [System.Net.NetworkInformation.NetworkInterface]::GetIsNetworkAvailable()) { return }

    Set-Content -LiteralPath $stateFile -Value (Get-Date).ToString('o')

    $job = Start-Job -Name 'DevEnvUpdateCheck' -ScriptBlock {
        param($repoPath)
        try {
            git -C $repoPath fetch --quiet origin 2>$null | Out-Null
            $local  = (git -C $repoPath rev-parse HEAD 2>$null).Trim()
            $remote = (git -C $repoPath rev-parse '@{u}' 2>$null).Trim()
            if (-not $remote -or $local -eq $remote) { return }
            git -C $repoPath merge-base --is-ancestor HEAD '@{u}' 2>$null
            if ($LASTEXITCODE -ne 0) { return } # diverged or local is ahead
            $changed = git -C $repoPath diff --name-only $local $remote 2>$null
            $profileChanged = @($changed) -match '^(pwsh/|ohmyposh/|bootstrap/)'
            [pscustomobject]@{
                UpdateAvailable = $true
                ProfileChanged  = [bool]$profileChanged
                LocalSha        = $local.Substring(0, [Math]::Min(8, $local.Length))
                RemoteSha       = $remote.Substring(0, [Math]::Min(8, $remote.Length))
                ChangedFiles    = @($changed)
            }
        } catch {}
    } -ArgumentList $repo

    $handler = {
        if ($Sender.State -in 'Completed','Failed','Stopped') {
            try {
                $result = Receive-Job -Job $Sender -ErrorAction SilentlyContinue
                if ($result -and $result.UpdateAvailable) {
                    Write-Host ""
                    if ($result.ProfileChanged) {
                        Write-Host ("[DevEnv] update available {0}..{1} - profile-related files changed. Run 'devenv-update'." -f $result.LocalSha, $result.RemoteSha) -ForegroundColor Yellow
                    } else {
                        Write-Host ("[DevEnv] update available {0}..{1}. Run 'devenv-update'." -f $result.LocalSha, $result.RemoteSha) -ForegroundColor DarkYellow
                    }
                }
            } finally {
                Remove-Job -Job $Sender -Force -ErrorAction SilentlyContinue
                Unregister-Event -SourceIdentifier $EventSubscriber.SourceIdentifier -ErrorAction SilentlyContinue
            }
        }
    }

    $sourceId = "DevEnvUpdateCheck_$($job.Id)"
    Register-ObjectEvent -InputObject $job -EventName StateChanged -SourceIdentifier $sourceId -Action $handler | Out-Null

    # Race guard: if the job already completed before the handler attached,
    # invoke the handler manually with a synthetic context.
    if ($job.State -in 'Completed','Failed','Stopped') {
        try {
            $result = Receive-Job -Job $job -ErrorAction SilentlyContinue
            if ($result -and $result.UpdateAvailable) {
                Write-Host ""
                if ($result.ProfileChanged) {
                    Write-Host ("[DevEnv] update available {0}..{1} - profile-related files changed. Run 'devenv-update'." -f $result.LocalSha, $result.RemoteSha) -ForegroundColor Yellow
                } else {
                    Write-Host ("[DevEnv] update available {0}..{1}. Run 'devenv-update'." -f $result.LocalSha, $result.RemoteSha) -ForegroundColor DarkYellow
                }
            }
        } finally {
            Remove-Job -Job $job -Force -ErrorAction SilentlyContinue
            Unregister-Event -SourceIdentifier $sourceId -ErrorAction SilentlyContinue
        }
    }
}

function global:devenv-update {
    if (-not $env:pwsh_devenv) { Write-Error "env:pwsh_devenv not set"; return }
    Push-Location $env:pwsh_devenv
    try {
        git pull --ff-only
        Write-Host "Profile updated. Re-bootstrap (Admin) if needed: $env:pwsh_devenv\bootstrap\Configure-DevBox.ps1" -ForegroundColor Cyan
        Write-Host "Or just reload your profile:  . `$PROFILE.CurrentUserAllHosts" -ForegroundColor DarkGray
    } finally { Pop-Location }
}

Write-Host "DevEnv profile loaded from $env:pwsh_devenv" -ForegroundColor DarkGray
Start-DevEnvUpdateCheck