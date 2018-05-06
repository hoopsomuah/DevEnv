if(get-module pscx -ListAvailable)
{
    Write-Output "Importing PowerShell Community Extensions"
    Import-Module pscx -NoClobber -arg "$PSScriptRoot\Pscx.UserPreferences.ps1"
} else {
    Write-Output "PowerShell Community Extensions are not available. Not importing module"
}

if(get-module poshgit -ListAvailable)
{
    Write-Output "Importing POSH Git"
    Import-Module poshgit -NoClobber 
} else {
    Write-Output "PowerShell Git Module not available. Not importing"
}

#-----------------------------------------------------------------------------------------------------------------
#-----------------------------------------------------------------------------------------------------------------
function global:Update-GitRepositories{
  get-childitem -r -h -i ".git" | 
    ForEach-Object { 
      $d= $(split-path -parent $_)
      Write-Output "pulling $d..."
      Set-Location $d
      git fetch origin
      #TODO: if nothing is staged, maybe do a pull instead
    }
}

set-alias gfetch Update-GitRepositories

#-----------------------------------------------------------------------------------------------------------------
# Drive Aliases
#-----------------------------------------------------------------------------------------------------------------

$driveAliases = @{}

$driveAliases['src'] = join-path $env:userprofile "source"
$driveAliases['repos'] = join-path $driveAliases['src'] "repos"

$driveAliases['eShop'] = join-path $driveAliases['repos'] "eShop"
$driveAliases['ugrt'] = join-path $driveAliases['repos'] "UserGraph"

$alternateDriveFunctionNames = @{}
$alternateDriveFunctionNames['variable'] = "var"
$alternateDriveFunctionNames['function'] = "fn"

# Create new PS Drives
foreach($d in $driveAliases.GetEnumerator())
{
  if(-not (test-path $d.Value))
    {
        Write-Host "Not creating $($d.Key): because the path $($d.Value) does not exist"
        continue
    }

    if(test-path "$($d.Key):")
    {
        Write-Host "Not creating $($d.Key): because the drive is already in use"
        continue
    }

  new-psdrive $d.Key FileSystem $d.Value -Scope Global | out-null

}

# Replace PS Drive Functions
foreach ($d in Get-PSDrive)
{
  if(test-path "function:global:$($d.Name):")
  {
    remove-item -path "function:\$($d.Name):"
  }

  $functionName = $alternateDriveFunctionNames[$d.Name]
  if($functionName -eq $null) { $functionName = "$($d.Name)" }

  $scriptBlock = "Set-Location $($d.Name):"
  new-item -path "function:global:$($functionName):" -value $scriptBlock | out-null
}

#-----------------------------------------------------------------------------------------------------------------
# Figure out if we're running as an elevated (UAC) process
#-----------------------------------------------------------------------------------------------------------------

$script:wid=[System.Security.Principal.WindowsIdentity]::GetCurrent()
$script:prp=new-object System.Security.Principal.WindowsPrincipal($wid)
$script:adm=[System.Security.Principal.WindowsBuiltInRole]::Administrator
$script:isAdmin = $prp.IsInRole($adm)

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
  if($isAdmin){
    $usernameColor = "red"
  }

  write-host "$env:USERNAME@$($env:COMPUTERNAME.toLower()) "  -nonewline -ForegroundColor $usernameColor

  #write-host -nonewline '[' -ForegroundColor $fColor

  $nondrivePath = split-path $location.Path -noqualifier

  if($location.Path.ToLower().StartsWith($env:USERPROFILE.ToLower()))
  {
      write-host -nonewline "~$($location.ProviderPath.Substring($env:USERPROFILE.Length))" -ForegroundColor $fColor
  }
  elseif($location.Drive -eq $null)
  {
      write-host -nonewline $nondrivePath -ForegroundColor $fColor
  }
  else
  {
      $pathParts = @()
      while(($nondrivePath -ne "\") -and ($nondrivePath -ne ""))
      {
        $pathParts = @(split-path $nondrivePath -leaf) + $pathParts
        $nondrivePath = split-path $nondrivePath -parent
      }
      write-host -nonewline $location.Drive.Name -ForegroundColor $fColor
      write-host -nonewline ':'  -ForegroundColor $fColor
      $pathParts | % {
        write-host -nonewline '\'  -ForegroundColor $fColor

        write-host -nonewline $_  -ForegroundColor $fColor
      }
  }
  write-host #']'  -ForegroundColor $fColor

  # enable posh-git in prompt if it's loaded
  # ----------------------------------------------------------------------------
  if($gitInPrompt)
  {
      $realLASTEXITCODE = $LASTEXITCODE
      Write-VcsStatus

      $global:LASTEXITCODE = $realLASTEXITCODE
  }


  write-host -nonewline (new-object string '$', ($nestedPromptLevel + 1))
  return " "
}

