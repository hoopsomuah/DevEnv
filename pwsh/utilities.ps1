
#-----------------------------------------------------------------------------------------------------------------
function Set-PsDriveFunctions {
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
}
# confirm-action - Prompt for confirmation
#-----------------------------------------------------------------------------------------------------------------
function Confirm-Action {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message    
    )
    do {
        $response = Read-Host "$Message (Y/N)"
    } while ($response -notmatch "^[yn]$")

    return $response -eq "y"
}


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
set-alias gremote Get-GitRemotes

function Replace-PsDriveFunctions {
    # Replace PS Drive Functions
    foreach ($d in Get-PSDrive) {
        if (test-path "function:global:$($d.Name):") {
            remove-item -path "function:\$($d.Name):"
        }

        $functionName = "$($d.Name)"

        $scriptBlock = "Set-Location $($d.Name):"
        new-item -path "function:global:$($functionName):" -value $scriptBlock | out-null
    }
}

set-alias codei code-insiders.cmd -Scope Global
set-alias e code-insiders.cmd -Scope Global
