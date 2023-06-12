if (!(Get-Module posh-git -ListAvailable)) {
    $installPoshGit = Read-Host "The posh-git module is not installed. Do you want to install it? (Y/N)"
    if ($installPoshGit -eq "Y") {
        Install-Module posh-git -Scope CurrentUser -Force 
    }
}

if (!(Get-Module PSReadLine -ListAvailable)) {
    $installPSReadLine = Read-Host "The PSReadLine module is not installed. Do you want to install it? (Y/N)"
    if ($installPSReadLine -eq "Y") {
        Install-Module -Name PSReadLine -AllowPrerelease -Scope CurrentUser -Force
    }
}

if (!(winget list -e JanDeDobbeleer.OhMyPosh)) {
    $installOhMyPosh = Read-Host "Oh My Posh is not installed. Do you want to install it using Winget? (Y/N)"
    if ($installOhMyPosh -eq "Y") {
        winget install JanDeDobbeleer.OhMyPosh
    }
}
# copy the contents of the bootstrap folder to the users powershell script folder
Copy-Item -Path "$PSScriptRoot\bootstrap\profile.ps1" -Destination $Profile.CurrentUserAllHosts -Recurse -Force
