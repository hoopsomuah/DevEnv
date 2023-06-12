
$env:POSH_GIT_ENABLED = $true

#-----------------------------------------------------------------------------------------------------------------
# gfetch - recursively fetch
#-----------------------------------------------------------------------------------------------------------------
function global:Update-GitRepositories {
    get-childitem -r -h -i ".git" |
        ForEach-Object {
        $d = $(split-path -parent $_)
        Write-Output "fetching $d..."
        Push-Location $d
        $status = Get-GitStatus
        if($status.HasWorking)
        {
            git fetch --all
        } else {
            git pull --all
        }
        Pop-Location
        #TODO: if nothing is staged, maybe do a pull instead
    }
}

set-alias gfetch Update-GitRepositories

#-----------------------------------------------------------------------------------------------------------------
# gremote - List all remotes
#-----------------------------------------------------------------------------------------------------------------
function global:Get-GitRemotes {
    get-childitem -r -h -i ".git" |
        ForEach-Object {
        $d = $(split-path -parent $_)
        Write-Output "Remotes for $d..."
        Push-Location $d
        git remote -v
        Write-Output ""
        Pop-Location
        #TODO: if nothing is staged, maybe do a pull instead
    }
}

set-alias gfetch Update-GitRepositories
set-alias gremote Get-GitRemotes

#-----------------------------------------------------------------------------------------------------------------
# Drive Aliases
#
# This section creates PowerShell drives for some common directories
#
#-----------------------------------------------------------------------------------------------------------------

$driveAliases = @{}

$driveAliases['src'] = join-path $env:userprofile "source"
$driveAliases['repos'] = join-path $driveAliases['src'] "repos"
$driveAliases["oss"] = join-path $driveAliases['repos'] "oss"


$alternateDriveFunctionNames = @{}
$alternateDriveFunctionNames['variable'] = "var"
$alternateDriveFunctionNames['function'] = "fn"

# See https://www.nerdfonts.com/cheat-sheet
$driveGlyphs = @{}
$driveGlyphs["meow"] = "🐱"
$driveGlyphs["oss"] = "$([char]0xf09b)"
$driveGlyphs["cc"] = "$([char]0xf0c1)"

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

#-----------------------------------------------------------------------------------------------------------------
# Figure out if we're running as an elevated (UAC) process
#-----------------------------------------------------------------------------------------------------------------

$script:wid = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$script:prp = new-object System.Security.Principal.WindowsPrincipal($wid)
$script:adm = [System.Security.Principal.WindowsBuiltInRole]::Administrator
$script:isAdmin = $prp.IsInRole($adm)


$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$ompPath = Join-Path $scriptPath "hoop.omp.json"
oh-my-posh init pwsh --config $ompPath | Invoke-Expression

