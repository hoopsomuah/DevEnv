if(get-module pscx -ListAvailable)
{
    write "Importing PowerShell Community Extensions"
    Import-Module pscx -NoClobber -arg "$PSScriptRoot\Pscx.UserPreferences.ps1"
} else {
  write "PowerShell Community Extensions are not available. Not importing module"
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

