<# if (get-module pscx -ListAvailable) {
    Write-Output "Importing PowerShell Community Extensions"
    Import-Module pscx -NoClobber -arg "$PSScriptRoot\Pscx.UserPreferences.ps1"
}
else {
    Write-Output "PowerShell Community Extensions are not available. Not importing module"
}

if (get-module posh-git -ListAvailable) {
    Write-Output "Importing POSH Git"
    Import-Module poshgit -NoClobber 
}
else {
    Write-Output "PowerShell Git Module not available. Not importing"
} #>

#-----------------------------------------------------------------------------------------------------------------
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
# Drive Aliases
#
# This section creates PowerShell drives for some common directories
#
#-----------------------------------------------------------------------------------------------------------------

$driveAliases = @{}

$driveAliases['src'] = join-path $env:userprofile "source"
$driveAliases['repos'] = join-path $driveAliases['src'] "repos"
$driveAliases['mrs'] = join-path $driveAliases['repos'] "mrs"
$driveAliases['ou'] = join-path $driveAliases['mrs'] "ou"


$alternateDriveFunctionNames = @{}
$alternateDriveFunctionNames['variable'] = "var"
$alternateDriveFunctionNames['function'] = "fn"

# Create new PS Drives
foreach ($d in $driveAliases.GetEnumerator()) {
    if (-not (test-path $d.Value)) {
        Write-Host "Not creating $($d.Key): because the path $($d.Value) does not exist"
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
    if ($functionName -eq $null) { $functionName = "$($d.Name)" }

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




function Import-GitModule($Loaded) {
    if ($Loaded) { return }
    $GitModule = Get-Module -Name Posh-Git -ListAvailable
    if ($GitModule | Select-Object version | Where-Object version -le ([version]"0.6.1.20160330")) {
        Import-Module Posh-Git > $null
    }
    if (-not ($GitModule) ) {
        Write-Warning "Missing git support, install posh-git with 'Install-Module posh-git' and restart cmder."
    }
    # Make sure we only run once by alawys returning true
    return $true
}



$isGitLoaded = $false
#Anonymice Powerline
$arrowSymbol = [char]0xE0B0;
$branchSymbol = [char]0xE0A0;

$defaultForeColor = "White"
$defaultBackColor = "Black"
$pathForeColor = "White"
$pathBackColor = "DarkBlue"
$gitCleanForeColor = "White"
$gitCleanBackColor = "DarkGreen"
$gitDirtyForeColor = "Black"
$gitDirtyBackColor = "Yellow"

function Write-GitPrompt() {
    $status = Get-GitStatus

    if ($status) {

        # assume git folder is clean
        $gitBackColor = $gitCleanBackColor
        $gitForeColor = $gitCleanForeColor
        if ($status.HasWorking -Or $status.HasIndex) {
            # but if it's dirty, change the back color
            $gitBackColor = $gitDirtyBackColor
            $gitForeColor = $gitDirtyForeColor
        }

        # Close path prompt
        Write-Host $arrowSymbol -NoNewLine -BackgroundColor $gitBackColor -ForegroundColor $pathBackColor

        # Write branch symbol and name
        Write-Host " " $branchSymbol " " $status.Branch " " -NoNewLine -BackgroundColor $gitBackColor -ForegroundColor $gitForeColor

        <# Git status info
        HasWorking   : False
        Branch       : master
        AheadBy      : 0
        Working      : {}
        Upstream     : origin/master
        StashCount   : 0
        Index        : {}
        HasIndex     : False
        BehindBy     : 0
        HasUntracked : False
        GitDir       : D:\amr\SourceCode\DevDiary\.git
        #>

        # close git prompt
        Write-Host $arrowSymbol -NoNewLine -BackgroundColor $defaultBackColor -ForegroundColor $gitBackColor
    } else {
        Write-Host $arrowSymbol -NoNewLine -ForegroundColor $pathBackColor
    }
}

function getGitStatus($Path) {
    if (Test-Path -Path (Join-Path $Path '.git') ){
        $isGitLoaded = Import-GitModule $isGitLoaded
        Write-GitPrompt
        return
    }
    $SplitPath = split-path $path
    if ($SplitPath) {
        getGitStatus($SplitPath)
    }
    else {
        Write-Host $arrowSymbol -NoNewLine -ForegroundColor $pathBackColor
    }
}

#-----------------------------------------------------------------------------------------------------------------
# Set prompt creation function
#-----------------------------------------------------------------------------------------------------------------
set-item -path 'function:global:prompt' -value {

    #write-host -nonewline -f Green ((get-history -Count 1).ID + 1)
    $location = get-location

    #break the path into pieces

    $fColor = "yellow"
    write-host

    $usernameColor = "darkgreen"
    if ($isAdmin) {
        $usernameColor = "red"
    }

    $tp = $PWD.Path.replace($env:USERPROFILE, "~")
    Write-Host " $tp " -NoNewLine -BackgroundColor $pathBackColor -ForegroundColor $pathForeColor

    Write-GitPrompt
    Write-Host

    Write-Host "$env:USERNAME@$($env:COMPUTERNAME.toLower())"  -NoNewLine -ForegroundColor $usernameColor
    Write-Host -NoNewLine '🔥' # -ForegroundColor $fColor
    return " "
}

