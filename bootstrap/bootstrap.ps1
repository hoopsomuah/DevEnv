<#
.SYNOPSIS
    Web Bootstrap script for a new machine.
.NOTES
    Invoke-WebRequest -Headers @{"Cache-Control"="no-cache"} -UseBasicParsing "https://raw.githubusercontent.com/hoopsomuah/DevEnv/master/bootstrap.ps1" | Invoke-Expression
#>
$repo = "hoopsomuah/DevEnv"
$repoUrl = "https://github.com/$repo.git"

function Confirm-Action {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$Message
    )
    do {
        $response = Read-Host "$Message (Y/N)"
    } while ($response -notmatch "^[yn]$")

    return $response -eq "y"
}

function Delete-DevEnvFolder {
    if(Confirm-Action "Delete $env:pwsh_devenv?") {
        Remove-Item $env:pwsh_devenv -Recurse -Force
        return $true;
    }
    else {
        return $false;
    }
}

function Is-FullDevEnvFolder
{
    param (
        [Parameter(Mandatory=$true)]
        [string]$Location
    )
    if((Test-Path $Location\pwsh\profile.ps1)
    -and (Test-Path $Location\bootstrap\Configure-DevBox.ps1)
    -and (Test-Path $Location\bootstrap\bootstrap.ps1)
        -and (Test-Path $Location\pwsh\utilities.ps1)
        -and (Test-Path $Location\winget)
        -and (Test-Path $Location\ohmyposh))
}

[bool]$cloneRepo = $false
[bool]$relaunch = $true

$choices = [System.Management.Automation.Host.ChoiceDescription[]]@()
$message = "env:pwsh_devenv is set to an existing devEnv folder?"
$caption = "Bootstrap DevEnv"
$defaultChoice = 0

$defaultLocation = "$HOME\src\DevEnv\"
$devEnvSpecified = Test-Path env:pwsh_devenv

$scriptParentFolder = (Split-Path $PSScriptRoot -Parent)
$scriptRootIsDevEnvCandidate = Is-FullDevEnvFolder -Location $scriptParentFolder
if($scriptRootIsDevEnvCandidate) {
        $keepBootstrappingChoice = $choices.Count
        $choices += "&Bootstrap From $scriptParentFolder"
}

$devEnvExists = $devEnvSpecified ? Test-Path $env:pwsh_devenv : $false

$cloneLocation = $devEnvSpecified ? $env:pwsh_devenv : $d
$existingDevEnvIsReal = $false
$runningUnderExistingDevEnv = $false;

if($devEnvExists) {
    $runningUnderExistingDevEnv = $env:pwsh_devenv -eq (Split-Path $PSScriptRoot -Parent)
    $existingDevEnvIsReal = $devEnvExists Is-FullDevEnvFolder -Location $env:pwsh_devenv
     if(-not $existingDevEnvIsReal) { Write-Warning "The specified path $env:pwsh_devenv is not a valid DevEnv folder" }        
} else {
    Write-Warning "env:pwsh_devenv set to $defaultPath which does not exist."
}

if(-not $runningUnderExistingDevEnv){
    
    if($devEnvSpecified){
        Write-Warning "The current script is not running under the specified DevEnv folder" 
        if($existingDevEnvIsReal) {
            Write-Host "The specified path $env:pwsh_devenv is a valid DevEnv folder"
            $relaunchChoice = $choices.Count
            $choices = "&Relaunch Bootstrap from that folder" + $choices
        }    
    }

    $cleanCloneChoice = $choices.Count
    $choices += "&Clean, Clone and Configure the DevEnv repo at $cloneLocation"
}

$providePathChoice = $choices.Count
$choices += "&Specify a path to clone the DevEnv repo to"
$cancelChoice = $choices.Count
$choices += "Cancel and e&xit"
            

$result = $Host.UI.PromptForChoice($caption,$message,$choices,$defaultChoice)

switch ($result) {
    $keepBootstrappingChoice { 
        $env:pwsh_devenv = $scriptParentFolder
        $cloneRepo = $false
        $relaunch = $false;

    } $relaunchChoice { 
        $cloneRepo = $false
        $relaunch = $true;

    } $cleanCloneChoiceChoice { 
        #delete the existing folder and clone the repo
        Delete-DevEnvFolder
        $cloneRepo = $true

    } $providePathChoice {
        #ask the user to provide a path to clone the repo. If they don't, use the default

        do {
            $userPath = Read-Host -Prompt "Enter a path to clone the DevEnv repo to (default: $defaultPath)"
            if (-not $userPath) {
                $userPath = $defaultPath
            }
        } while (Test-Path $userPath)
        $cloneLocation = $userPath
        $cloneRepo = $true
        
    } $cancelChoice {
        Write-Warning "Unable to set up DevEnv."
        exit -1
    }
}

if($cloneRepo) {
    if (-not(Get-Command git.exe -ErrorAction SilentlyContinue))
    {
        if(Confirm-Action "Git is not installed. Install Git?") {
            Write-Host "Installing Git"
            winget.exe install -e --id Git.Git    

            #refresh the path
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
            return $true
        }
        else {
            Write-Warning "Skipping Git installation. Git is required to clone the DevEnv repo"
            return $false
        }
    }

    Write-Host "Cloning $repoUrl"
    git.exe clone $repoUrl $cloneLocation
    $env:pwsh_devenv = $cloneLocation
}

if($relaunch) {
    $newBootstrap = "$env:pwsh_devenv\bootstrap\bootstrap.ps1"
    Write-Host "Running $newBootstrap"
    & $newBootstrap
    exit $LASTEXITCODE
}

Write-Host "Running Configure-DevBox script"
& .\Configure-DevBox.ps1 
