Import-Module VisualStudio -NoClobber

# This needs to be here in order to make sure PSCX doesn't clobber the commands.
Import-Module Microsoft.PowerShell.Archive

if(get-module pscx -ListAvailable)
{
    write "Importing PSCX"
    Import-Module pscx -NoClobber -arg (join-path $PSScriptRoot SkyDrive.Pscx.UserPreferences.ps1)
} else {
  write "PowerShell Community Extensions are not available. Not importing module"
}


where.exe git 1>$null 2>&1

$gitInstalled = $?
if($gitInstalled)
{
    Import-Module posh-git
}

$gitInPrompt = $gitInstalled -and (get-module posh-git)

#-----------------------------------------------------------------------------------------------------------------
# Drive Aliases
#-----------------------------------------------------------------------------------------------------------------

$driveAliases = @{}
$driveAliases['src'] = join-path $env:userprofile "src"

if($SkyDrivePath)
{
    $driveAliases['SkyDrive'] = "$SkyDrivePath"
}


if($env:COMPUTERNAME -eq "hsomu-dell")
{
    $driveAliases['src'] = join-path $env:userprofile "src"
    $srcDir = $driveAliases['src']

    $tfsRoot = "$srcDir\Workspaces"
    if(test-path $tfsRoot)
    {
        $driveAliases['tfs'] = $tfsRoot
        $driveAliases['nebula'] = "$tfsRoot\nebula"
        $driveAliases['Section3'] = "$tfsRoot\343 Section 3"
        $driveAliases['s3'] = $driveAliases['Section3']
        $driveAliases['orleans'] = "$tfsRoot\Data Center Futures\Orleans"
        $driveAliases['Section3'] = "$tfsRoot\343 Section 3"
        $driveAliases['hsomu'] = "$tfsRoot\343 Section 3\Users\hsomu"
        $driveAliases['lab1'] = "$tfsRoot\343 Section 3\Users\hsomu\lab1"
    }

    $env:NuGetLocalPackageSource="$tfsRoot\Services\NuGetRepository"
    $env:NuGetPackageOutputDir="$tfsRoot\Services\NuGetRepository"
} elseif($env:COMPUTERNAME -eq "hsomu-mac-lt") {
    $srcDir = $driveAliases['src']

    $driveAliases['git'] = "$srcDir\git"

    $tfsRoot = "$srcDir\tfs"
    if(test-path $tfsRoot)
    {
        $driveAliases['tfs'] = $tfsRoot
        $driveAliases['nebula'] = "$tfsRoot\nebula"
        $driveAliases['Section3'] = "$tfsRoot\343 Section 3"
        $driveAliases['orleans'] = "$tfsRoot\Data Center Futures\Orleans"
        $driveAliases['Section3'] = "$tfsRoot\343 Section 3"
        $driveAliases['lab1'] = "$tfsRoot\343 Section 3\Users\hsomu\lab1"
    }

    $env:NuGetLocalPackageSource="$tfsRoot\Services\NuGetRepository"
    $env:NuGetPackageOutputDir="$tfsRoot\Services\NuGetRepository"
}
elseif($env:COMPUTERNAME -eq "hsomu-mac")
{
    $srcDir = $driveAliases['src']

    $driveAliases['git'] = "$srcDir\git"

    $tfsRoot = "$srcDir\tfs"
    if(test-path $tfsRoot)
    {
        $driveAliases['tfs'] = $tfsRoot
        $driveAliases['nebula'] = "$tfsRoot\nebula"
        $driveAliases['343-Section3'] = "$tfsRoot\343"
    }

    $env:NuGetLocalPackageSource="$tfsRoot\Services\NuGetRepository"
    $env:NuGetPackageOutputDir="$tfsRoot\Services\NuGetRepository"
}
elseif($env:COMPUTERNAME -eq "ANANSE2")
{
    $srcDir = $driveAliases['src']

    $tfs1Root = "$srcDir\343tfs"

    if(test-path $tfs1Root)
    {
        $driveAliases['tfs'] = $tfs1Root

        $driveAliases['nebula'] = "$tfs1Root\Services\NebulaMain"
        $driveAliases['title-files'] = "$tfs1Root\Services\Main\Products\TitleFiles"
        $driveAliases['presence'] = "$tfs1Root\Services\Main\Products\presence"
        $driveAliases['stats'] = "$tfs1Root\Services\Main\Products\Stats"
    }

}
elseif($env:COMPUTERNAME -eq "HSOMU-DEV")
{
    $driveAliases['src'] = "d:\src"
    $driveAliases['nebula'] = "D:\src\tfs\StudiosNebula"
    $driveAliases['git'] = "d:\src\git"

    $tfs1Root = "D:\src\tfs"

    if(test-path $tfs1Root)
    {
        $driveAliases['tfs'] = $tfs1Root
        $driveAliases['main'] = "$tfs1Root\343-Section3\Services\Main"
    }
}



$alternateDriveFunctionNames = @{}
$alternateDriveFunctionNames['variables'] = "var:"

New-AliasDrives $driveAliases $alternateDriveFunctionNames

#-----------------------------------------------------------------------------------------------------------------
# This replaces the Edit-File function defined by PSCX to make it support drive aliases
#-----------------------------------------------------------------------------------------------------------------
function global:Edit-File
{
[CmdletBinding(DefaultParameterSetName="Path", SupportsShouldProcess=$true)]

    param(
        [Parameter(Position=0,
                   ParameterSetName="Path",
                   ValueFromPipeline=$true,
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Path,

        [Alias("PSPath")]
        [Parameter(Position=0,
                   ParameterSetName="LiteralPath",
                   ValueFromPipelineByPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $LiteralPath
    )

    Begin {
        $editor = 'Notepad.exe'
        $preferredEditor = $Pscx:Preferences['TextEditor']
        if ($preferredEditor) {
            Get-Command $preferredEditor 2>&1 | out-null
            if ($?) {
                $editor = $Pscx:Preferences['TextEditor']
            }
            else {
                $pscmdlet.WriteDebug("Edit-File editor preference '$preferredEditor' not found, defaulting to $editor")
            }
        }

        $pscmdlet.WriteDebug("Edit-File editor is $editor")
        function EditFileImpl($path) {
            & $editor $path
        }
    }

    Process
    {
        if ($psCmdlet.ParameterSetName -eq "Path")
        {
            $resolvedPaths = $null
            if ($Path)
            {
                $resolvedPaths = @()
                # In the non-literal case we may need to resolve a wildcarded path
                foreach ($apath in $Path)
                {
                    if (Test-Path $apath)
                    {
                        $resolvedPaths += @(Resolve-Path $apath | Foreach { $_.ProviderPath })
                    }
                    else
                    {
                        $resolvedPaths += $apath
                    }
                }
            }
        }
        else
        {
            $resolvedPaths = $LiteralPath
        }

        if ($resolvedPaths -eq $null)
        {
            $pscmdlet.WriteVerbose("Edit-File opening <no path specified>")
            if ($pscmdlet.ShouldProcess("<no path specified>"))
            {
                EditFileImpl
            }
        }
        else
        {
            foreach ($rpath in $resolvedPaths)
            {
                $PathIntrinsics = $ExecutionContext.SessionState.Path

                if ($PathIntrinsics.IsProviderQualified($rpath))
                {
                    $rpath = $PathIntrinsics.GetUnresolvedProviderPathFromPSPath($rpath)
                }

                $pscmdlet.WriteVerbose("Edit-File opening $rpath")
                if ($pscmdlet.ShouldProcess("$rpath"))
                {
                    EditFileImpl $rpath
                }
            }
        }
    }
}

function edit-fileLiteral($path)
{
  edit-file -literalPath $path
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

  $fColor = "DarkYellow"
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

