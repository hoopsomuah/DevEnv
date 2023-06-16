$repo = "hoopsomuah/DevEnv"
$repoUrl = "https://github.com/$repo.git"

# Check if git is installed. If not, install it
if (-not(Get-Command git.exe -ErrorAction SilentlyContinue))
{
    if(Confirm-Action "Git is not installed. Install Git?")
    {
        Write-Host "Installing Git"
        winget.exe install -e --id Git.Git    

        #refresh the path
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }
    else 
    {
        Write-Warning "Skipping Git installation. Git is required to clone the DevEnv repo"
        exit
    }
}

#ask the user to provide a path to clone the repo. If they don't, use the default
$defaultPath = Test-Path env:pwsh_devenv ? $env:pwsh_devenv : "$HOME\src\DevEnv\"
$userPath = Read-Host -Prompt "Enter a path to clone the DevEnv repo to (default: $defaultPath)"
$env:pwsh_devenv = $userPath ? $userPath : $defaultPath

function Delete-DevEnvFolder {
    if(Confirm-Action "The path $env:pwsh_devenv already exists. Delete existing folder?") {
        Write-Host "Deleting $env:pwsh_devenv"
        Remove-Item $env:pwsh_devenv -Recurse -Force
        return $true;
    }
    else {
        return $false;
    }
}

if(Test-path $env:pwsh_devenv)
{   
    #check if the folder is a git repo
    Push-Location $env:pwsh_devenv
    try
    {
        if(-not (git.exe rev-parse --is-inside-work-tree))
        {
            if(-not (Delete-DevEnvFolder))
            {
                Write-Warning "Skipping Repo Clone. The folder to clone into is not empty."
                exit
            }
        }
        else
        {
            $url = git.exe config --get remote.origin.url
            if($url -eq $repoUrl)
            {
                Write-Host "The path $env:pwsh_devenv is already a clone of $repoUrl"
                exit
            }
            else
            {
                Write-Warning "The path $env:pwsh_devenv is already a git repo. It is not a clone of $repoUrl"
                if(-not (Delete-DevEnvFolder)) {
                    Write-Warning "Skipping Repo Clone. The folder to clone into is already syncing another repo."
                    exit
                }
            }
        }
    }
    finally
    {
        Pop-Location
    }
}


Write-Host "Cloning $repoUrl"
git.exe clone $repoUrl $env:pwsh_devenv