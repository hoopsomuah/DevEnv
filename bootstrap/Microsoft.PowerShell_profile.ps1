. $HOME\source\repos\PowerShell\Set-DevelopmentEnvironment.ps1

if((Get-Item $env:SystemRoot\System32).Fullname -eq $pwd.Path)
{
    set-location  ~ | out-null
}