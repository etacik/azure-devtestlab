<##################################################################################################

    Description
    ===========

    - This script does the following - 
        - installs chocolatey
        - installs git
        - clones the specified git repo.
        - Creates url and lnk shortcuts to the git repo and local repo respectively.

    - The following logs are generated on the machine - 
        - Chocolatey's log : %ALLUSERSPROFILE%\chocolatey\logs folder.
        - This script's log : $PSScriptRoot\GitEnslister-{TimeStamp}\Logs folder.


    Usage examples
    ==============
    
    - Powershell -executionpolicy bypass -file GitEnlister.ps1 -GitRepoLocation "your repo URI" -PersonalAccessToken "access-token" 

    - Powershell -executionpolicy bypass -file GitEnlister.ps1 -GitRepoLocation "your repo URI" -PersonalAccessToken "access-token" -GitBranch "branch to check out"

    - Powershell -executionpolicy bypass -file GitEnlister.ps1 -GitRepoLocation "your repo URI" -PersonalAccessToken "access-token" -GitLocalRepoLocation "local folder location"


    Pre-Requisites
    ==============

    - Please ensure that this script is run elevated.
    - Please ensure that the powershell execution policy is set to unrestricted or bypass.


    Known issues / Caveats
    ======================
    
    - The 'git clone -b <branch-name>' command treats the branch-name as case-sensitive. Need
      to investigate further and resolve this. 


    Coming soon / planned work
    ==========================
    
    - We're currently installing git version 1.9.5.20150320 (last known good). See whether we 
      can roll forward to a newer version.

##################################################################################################>

#
# Arguments to this script file.
#

#
$GitRepoLocation = $args[0]

#
$GitLocalRepoLocation  = $args[1] 

#
$GitBranch = $args[2]

#
$PersonalAccessToken = $args[3]

# The location where this script resides. 
# Note: We cannot use $PSScriptRoot or $MyInvocation inside a script block. Hence passing 
# the location explicitly.
$ScriptRoot = $args[4]

##################################################################################################

#
# Powershell Configurations
#

# Note: Because the $ErrorActionPreference is "Stop", this script will stop on first failure.  
$ErrorActionPreference = "stop"

###################################################################################################

#
# Custom Configurations
#

$GitStableVersion = "1.9.5.20150320"
$GitEnlisterFolder = Join-Path $ScriptRoot -ChildPath $("GitEnlister-" + [System.DateTime]::Now.ToString("yyyy-MM-dd-HH-mm-ss"))

# Location of the log files
$ScriptLogFolder = Join-Path $GitEnlisterFolder -ChildPath "Logs"
$ScriptLog = Join-Path -Path $ScriptLogFolder -ChildPath "GitEnlister.log"
$ChocolateyInstallLog = Join-Path -Path $ScriptLogFolder -ChildPath "ChocolateyInstall.log"
$GitCloneStdOut = Join-Path -Path $ScriptLogFolder -ChildPath "GitClone.log"
$GitCloneStdErr = Join-Path -Path $ScriptLogFolder -ChildPath "GitClone.err"
$GitConfigStdOut = Join-Path -Path $ScriptLogFolder -ChildPath "GitConfig.log"
$GitConfigStdErr = Join-Path -Path $ScriptLogFolder -ChildPath "GitConfig.err"

##################################################################################################

# 
# Description:
#  - Displays the script argument values (default or user-supplied).
#
# Parameters:
#  - N/A.
#
# Return:
#  - N/A.
#
# Notes:
#  - Please ensure that the Initialize() method has been called at least once before this 
#    method. Else this method can only write to console and not to log files. 
#

function DisplayArgValues
{
    WriteLog "========== Configuration =========="
    WriteLog $("-GitRepoLocation : " + $GitRepoLocation)
    WriteLog $("-GitLocalRepoLocation : " + $GitLocalRepoLocation)
    WriteLog $("-GitBranch : " + $GitBranch)
    WriteLog $("-PersonalAccessToken : " + $PersonalAccessToken)
    WriteLog "========== Configuration =========="
}

##################################################################################################

# 
# Description:
#  - Creates the folder structure which'll be used for dumping logs generated by this script and
#    the logon task.
#
# Parameters:
#  - N/A.
#
# Return:
#  - N/A.
#
# Notes:
#  - N/A.
#

function InitializeFolders
{
    if ($false -eq (Test-Path -Path $GitEnlisterFolder))
    {
        New-Item -Path $GitEnlisterFolder -ItemType directory | Out-Null
    }

    if ($false -eq (Test-Path -Path $ScriptLogFolder))
    {
        New-Item -Path $ScriptLogFolder -ItemType directory | Out-Null
    }
}

##################################################################################################

# 
# Description:
#  - Writes specified string to the console as well as to the script log (indicated by $ScriptLog).
#
# Parameters:
#  - $message: The string to write.
#
# Return:
#  - N/A.
#
# Notes:
#  - N/A.
#

function WriteLog
{
    Param(
        <# Can be null or empty #> $message
    )

    $timestampedMessage = $("[" + [System.DateTime]::Now + "] " + $message) | % {
        Out-File -InputObject $_ -FilePath $ScriptLog -Append
    }
}

##################################################################################################

# 
# Description:
#  - Installs the chocolatey package manager.
#
# Parameters:
#  - N/A.
#
# Return:
#  - If installation is successful, then nothing is returned.
#  - Else a detailed terminating error is thrown.
#
# Notes:
#  - @TODO: Write to $chocolateyInstallLog log file.
#  - @TODO: Currently no errors are being written to the gitenlister.log. This needs to be fixed.
#

function InstallChocolatey
{
    Param(
        [ValidateNotNullOrEmpty()] $chocolateyInstallLog
    )

    WriteLog "Installing Chocolatey..."

    Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1')) | Out-Null

    WriteLog "Success."
}

##################################################################################################

# 
# Description:
#  - Returns the The 'leaf' name of git repo.
#
# Parameters:
#  - $gitRepoLocation: The HTTPS url of the git repository.
#
# Return:
#  - If installation is successful, then the 'leaf' name of the git repo is returned.
#  - Else a detailed terminating error is thrown.
#
# Notes:
#  - N/A.
#

function GetGitRepoLeaf
{
    Param(
        [ValidateNotNullOrEmpty()] $gitRepoLocation
    )

    $gitRepoLeaf = Split-Path -Path $gitRepoLocation -Leaf

    # replace any occurrences of '%20' with whitespace. 
    if ($gitRepoLeaf.Contains("%20"))
    {
        $gitRepoLeaf = $gitRepoLeaf.Replace("%20", " ")
    }

    # If appended by ".git", strip that out
    if ($gitRepoLeaf -like "*.git")
    {
        $gitRepoLeaf = $gitRepoLeaf -replace ".git", ""
    }

    return $gitRepoLeaf
}

##################################################################################################

#
# Description:
#  - Installs git client on the machine.
#  - Adds location of git.exe to the path. 
#
# Parameters:
#  - $gitVersion: The specific version of git to install.
#
# Return:
#  - If successful, then the location of git install folder is returned.
#  - Else a detailed terminating error is thrown.
#
# Notes:
#  - N/A.
#

function InstallGit
{
    Param(
        [ValidateNotNullOrEmpty()] $gitVersion
    )

    WriteLog $("Installing Git version: $gitVersion ...")

    # install git via chocolatey
    choco install git --version $gitVersion --force --yes --acceptlicense --verbose | Out-Null 

    if ($? -eq $false)
    {
        $errMsg = $("Error! Installation failed. Please see the chocolatey logs in %ALLUSERSPROFILE%\chocolatey\logs folder for details.")
        WriteLog $errMsg
        Write-Error $errMsg 
    }
    
    WriteLog "Success."
    

    # now find the location of git
    WriteLog "Finding location of Git.exe..."

    $gitInstallFolder = $null
    $gitBinariesFolder = $null
    $gitExeLocation = $null

    # Construct possible known paths to git.exe. We'll probe all these.
    $pathsToProbe = @(
        $(${env:ProgramFiles(x86)}),
        $(${env:ProgramFiles})
    )
    
    # Start probing.
    foreach($path in $pathsToProbe)
    {
        if ((Test-Path $($path + "\git")) -and (Test-Path $($path + "\git\bin")) -and (Test-Path $($path + "\git\bin\git.exe")))
        {
            $gitInstallFolder = $path + "\git"
            $gitBinariesFolder = $path + "\git\bin"
            $gitExeLocation = $path + "\git\bin\git.exe"
            break
        }
    }

    # bail out if git.exe was not found
    if ($null -eq $gitExeLocation)
    {
        $errMsg = $("Error! Git.exe could not be detected on this machine.")        
        WriteLog $errMsg
        Write-Error $errMsg -Category ObjectNotFound
    }

    WriteLog $("Success. Git.exe located at - " + $gitExeLocation)


    # now add the git binaries folder to the path
    WriteLog "Adding Git folder location to the PATH"

    # Check if the git binaries folder is already on the path
    if ($false -eq ($env:Path).Contains($gitBinariesFolder))
    {
        # Add it to the path.
        [Environment]::SetEnvironmentVariable("path", $($gitBinariesFolder + ";" + $env:Path), [System.EnvironmentVariableTarget]::Machine)    

        WriteLog "Success."
    }
    else
    {
        WriteLog "Git binaries folder location already exists on the PATH."
    }

    return $gitInstallFolder
}

##################################################################################################

#
# Description:
#  - Clones the specified git repo into specified local folder. 
#
# Parameters:
#  - $gitExeLocation: Location of git.exe. 
#  - $gitRepoLocation: The HTTPS clone url of the git repository.
#  - $gitLocalRepoLocation: The local folder into which the git repository will be cloned.
#  - $gitBranch: The branch that will be checked out.
#  - $stdOutLogfile: The log file to which the operation's stdout will be redirected.
#  - $stdErrLogfile: The log file to which the operation's stderr will be redirected.
#  - $personalAccessToken: The personal access token for authenticating to the git repo.
#
# Return:
#  - If git clone is successful, then nothing is returned.
#  - Else a detailed terminating error is thrown.
#
# Notes:
#  - N/A.
#

function CloneGitRepo
{
    Param(
        [ValidateNotNullOrEmpty()] $gitExeLocation,
        [ValidateNotNullOrEmpty()] $gitRepoLocation,
        [ValidateNotNullOrEmpty()] $gitLocalRepoLocation,
        [ValidateNotNullOrEmpty()] $gitBranch,
        [ValidateNotNullOrEmpty()] $stdOutLogfile,
        [ValidateNotNullOrEmpty()] $stdErrLogfile,
        [ValidateNotNullOrEmpty()] $personalAccessToken
        )

    # pre-condition checks
    if ($false -eq $gitRepoLocation.ToLowerInvariant().StartsWith("https://")) 
    {
        $errMsg = $("Error! The specified Git repo url is not a valid HTTPS clone url : " + $gitRepoLocation)
        WriteLog $errMsg
        Write-Error $errMsg 
    }
    if ($false -eq $gitRepoLocation.Length -gt 8)
    {
        $errMsg = $("Error! The specified Git repo url is not valid : " + $gitRepoLocation)
        WriteLog $errMsg
        Write-Error $errMsg 
    }


    # Using specified credentials, create the actual repo url to clone from.
    if ([string]::IsNullOrEmpty($personalAccessToken))
    {
        $gitRepoToUse = $gitRepoLocation
    }
    else
    {
        $protocolPrefix = "https://"
        $gitRepoNameSuffix = $gitRepoLocation.Substring(8)

        # HACK: If a personal access token is used in the clone URI, then the username is ignored. So 
        # any username can be used.
        $anyUserName = "AnyUserName"

        $gitRepoToUse = $("$protocolPrefix" + $anyUserName + ":" + $personalAccessToken + "@" + $gitRepoNameSuffix)
    }

    # Prep to start git.exe
    $args = $("clone -b " + $gitBranch + " " + $gitRepoToUse + " `"" + $gitLocalRepoLocation + "`"")

    WriteLog $("Cloning the git repo...")
    WriteLog $($gitExeLocation + " " + $args)

    # Run the git clone operation
    $p = Start-Process -FilePath $gitExeLocation -ArgumentList $args -RedirectStandardOutput $stdOutLogfile -RedirectStandardError $stdErrLogfile -PassThru -Wait

    # Was the clone operation successful?
    if ($p.ExitCode -ne 0)
    {
        $errMsg = $("Error! Git clone failed with exit code " + $p.ExitCode + ". Please see the log file: " + $stdErrLogfile)
        WriteLog $errMsg
        Write-Error $errMsg 
    }
    
    WriteLog $("Success. Git repo cloned at '" + $gitLocalRepoLocation + "'")
}

##################################################################################################

#
# Description:
#  - Runs some commonly used 'git config' commands
#  - Resets the git remote. 
#
# Parameters:
#  - $gitExeLocation: Location of git.exe.
#  - $bIgnoreGitExitCode : Set to $true to ignore the git.exe's exitcode.
#  - $gitRepoLocation: The HTTPS clone url of the git repository.
#  - $gitLocalRepoLocation: The local folder into which the git repository has been cloned.
#  - $stdOutLogfile: The log file to which the operation's stdout will be redirected.
#  - $stdErrLogfile: The log file to which the operation's stderr will be redirected.
#
# Return:
#  - If successful, then nothing is returned.
#  - Else a detailed terminating error is thrown.
#
# Notes:
#  - N/A.
#

function ConfigureGit
{
    Param(
        [ValidateNotNullOrEmpty()] $gitExeLocation,
        [ValidateNotNullOrEmpty()] $bIgnoreGitExitCode,
        [ValidateNotNullOrEmpty()] $gitRepoLocation,
        [ValidateNotNullOrEmpty()] $gitLocalRepoLocation,
        [ValidateNotNullOrEmpty()] $stdOutLogfile,
        [ValidateNotNullOrEmpty()] $stdErrLogfile
    )

    # list of git config commands
    $gitConfigCmds = @(
        "config --system core.safecrlf true"
        "config --system push.default simple"
        "config --system core.preloadindex true"
        "config --system core.fscache true"
        "config --system credential.helper wincred"
    )

    # execute each git config command
    foreach ($gitConfigCmd in $gitConfigCmds)
    {
        # Prep to start git.exe
        WriteLog $("Running git config...")
        WriteLog $($gitExeLocation + " " + $gitConfigCmd)

        # Run the git config gitConfigCmd
        $p = Start-Process -FilePath $gitExeLocation -ArgumentList $gitConfigCmd -PassThru -Wait

        # Was the config operation successful?
        if ($p.ExitCode -ne 0)
        {
            if ($true -eq $bIgnoreGitExitCode)
            {
                WriteLog $("Git.exe returned with exit code " + $p.ExitCode + ", which is being ignored as requested.")
            }
            else
            {
                $errMsg = $("Error! Git config failed with exit code " + $p.ExitCode + ". Please see the log file: " + $stdErrLogfile)
                WriteLog $errMsg
                Write-Error $errMsg 
            }
        }
        else
        {
            WriteLog "Success."
        }
    }

    # reset the git remote
    $gitResetRemoteCmd = $("remote set-url origin " + $gitRepoLocation)

    # Prep to start git.exe
    WriteLog $("Running git remote...")
    WriteLog $($gitExeLocation + " " + $gitResetRemoteCmd)

    # Run the git config gitConfigCmd. 
    # Ensure that the working directory is set to the local repo (since the 'git remote' command needs to be run from a local repo).
    $p = Start-Process -FilePath $gitExeLocation -ArgumentList $gitResetRemoteCmd -WorkingDirectory $gitLocalRepoLocation -RedirectStandardOutput $stdOutLogfile -RedirectStandardError $stdErrLogfile -PassThru -Wait

    # Was the config operation successful?
    if ($p.ExitCode -ne 0)
    {
        if ($true -eq $bIgnoreGitExitCode)
        {
            WriteLog $("Git.exe returned with exit code " + $p.ExitCode + ", which is being ignored as requested.")
        }
        else
        {
            $errMsg = $("Error! Git config failed with exit code " + $p.ExitCode + ". Please see the log file: " + $stdErrLogfile)
            WriteLog $errMsg
            Write-Error $errMsg 
        }
    }
    else
    {
        WriteLog "Success."
    }
}

##################################################################################################

#
# Description:
#  - Creates a desktop url shortcut to the git repo's project page (on VSO or Github etc). 
#
# Parameters:
#  - $gitRepoLocation: The HTTPS url of the git repository.
#  - $gitRepoLeaf: The 'leaf' name of git repo.
#
# Return:
#  - If successful, then nothing is returned.
#  - Else a detailed terminating error is thrown.
#
# Notes:
#  - Shortcuts are created on the public desktop (c:\users\public\desktop) in order to be 
#    accessible to all users.
#  - Naming convention for the shortcuts:
#    - "GitHub - {Repo short-name}" (if hosted on github. E.g. "GitHub - CoreFx").
#    - "VS Online - {Repo short-name}" (if hosted on visual studio online. E.g. "VS Online - CloudExplorer").
#    - "Project Page - {Repo short-name}" (if hosted elsewhere).
#

function CreateUrlDesktopShortcut
{
    Param(
        [ValidateNotNullOrEmpty()] $gitRepoLocation,
        [ValidateNotNullOrEmpty()] $gitRepoLeaf
    )

    $shell = New-Object -ComObject wscript.shell
    $desktopFolder = [System.Environment]::GetFolderPath("CommonDesktopDirectory")

    $urlShortcutName = $("Project Page - " + $gitRepoLeaf) 

    if ($gitRepoLocation -like "*visualstudio.com*")
    {
        $urlShortcutName = $("VS Online - " + $gitRepoLeaf) 
    }
    elseif ($gitRepoLocation -like "*github.com*")
    {
        $urlShortcutName = $("GitHub - " + $gitRepoLeaf) 
    }

    # prep the url shortcut to the git repo. 
    $urlShortcutPath = $($desktopFolder + "\" + $urlShortcutName + ".url")

    # create the shortcut only if it doesn't already exist.
    if ($false -eq (Test-Path -Path $urlShortcutPath))
    {
        $gitRepoLocationShortcut = $shell.CreateShortcut($urlShortcutPath)
        $gitRepoLocationShortcut.TargetPath = $gitRepoLocation

        # save the shortcut
        WriteLog $("Creating url shortcut to git repo...")
        WriteLog $("Shortcut file: '" + $urlShortcutPath + "'")
        WriteLog $("Shortcut target: '" + $gitRepoLocationShortcut.TargetPath + "'")
        WriteLog $("Shortcut args: '" + $gitRepoLocationShortcut.Arguments + "'")

        $gitRepoLocationShortcut.Save()

        WriteLog "Success."
    }
    else
    {
        WriteLog "Url shortcut to git repo already exists."
    }
}

##################################################################################################

#
# Description:
#  - Creates a .lnk desktop shortcut to the local repo (opens in file explorer).
#
# Parameters:
#  - $gitLocalRepoLocation: The local folder into which the git repository has been cloned.
#  - $gitRepoLeaf: The 'leaf' name of git repo.
#
# Return:
#  - If successful, then nothing is returned.
#  - Else a detailed terminating error is thrown.
#
# Notes:
#  - Shortcuts are created on the public desktop (c:\users\public\desktop) in order to be 
#    accessible to all users.
#

function CreateFileExplorerDesktopShortcut
{
    Param(
        [ValidateNotNullOrEmpty()] $gitLocalRepoLocation,
        [ValidateNotNullOrEmpty()] $gitRepoLeaf
    )

    $shell = New-Object -ComObject wscript.shell
    $desktopFolder = [System.Environment]::GetFolderPath("CommonDesktopDirectory")

    # now prep the lnk shortcut to the local repo (opens in file explorer)
    $lnkFileExplorerShortcutPath = $($desktopFolder + "\" + $gitRepoLeaf + ".lnk")

    # create the shortcut only if it doesn't already exist.
    if ($false -eq (Test-Path -Path $lnkFileExplorerShortcutPath))
    {
        $gitLocalRepoLocationFileExplorerShortcut = $shell.CreateShortcut($lnkFileExplorerShortcutPath)
        $gitLocalRepoLocationFileExplorerShortcut.TargetPath = $gitLocalRepoLocation
        $gitLocalRepoLocationFileExplorerShortcut.Description = $gitRepoLeaf
        $gitLocalRepoLocationFileExplorerShortcut.WindowStyle = 3

        # save the shortcut
        WriteLog $("Creating lnk file explorer shortcut to git local repo...")
        WriteLog $("Shortcut file: '" + $lnkFileExplorerShortcutPath + "'")
        WriteLog $("Shortcut target: '" + $gitLocalRepoLocationFileExplorerShortcut.TargetPath + "'")
        WriteLog $("Shortcut args: '" + $gitLocalRepoLocationFileExplorerShortcut.Arguments + "'")

        $gitLocalRepoLocationFileExplorerShortcut.Save()

        WriteLog "Success."
    }
    else
    {
        WriteLog "Lnk file explorer shortcut to git local repo already exists."
    }
}

##################################################################################################

#
# 
#

try
{
    # extract the leaf node/name of the git repo url.
    $gitRepoLeaf = GetGitRepoLeaf -gitRepoLocation $GitRepoLocation

    # We don't need to fully url-encode the repo url. However we should replace whitespaces with '%20'. 
    if ($GitRepoLocation.Contains(" "))
    {
        $GitRepoLocation = $GitRepoLocation.Replace(" ", "%20")
    }

    # ensure that the git repo leaf is appended to the local repo path (e.g. c:\Repos\coreclr).
    $GitLocalRepoLocation = Join-Path -Path $GitLocalRepoLocation -ChildPath $gitRepoLeaf


    #
    InitializeFolders

    #
    DisplayArgValues
    
    # install the chocolatey package manager
    InstallChocolatey -chocolateyInstallLog $ChocolateyInstallLog

    # install the git client
    $GitInstallFolder = InstallGit -gitVersion $GitStableVersion
    $GitExeLocation = Join-Path -Path $GitInstallFolder -ChildPath "\bin\git.exe"

    # clone the repo
    CloneGitRepo -gitExeLocation $GitExeLocation -gitRepoLocation $GitRepoLocation -gitLocalRepoLocation $GitLocalRepoLocation -gitBranch $GitBranch -stdOutLogfile $GitCloneStdOut -stdErrLogfile $GitCloneStdErr -personalAccessToken $PersonalAccessToken

    # run some commonly used git config commands    
    ConfigureGit -gitExeLocation $GitExeLocation -bIgnoreGitExitCode $false -gitRepoLocation $GitRepoLocation -gitLocalRepoLocation $GitLocalRepoLocation -stdOutLogfile $GitConfigStdOut -stdErrLogfile $GitConfigStdErr 

    # Create a desktop url shortcut to the git repo. 
    CreateUrlDesktopShortcut -gitRepoLocation $GitRepoLocation -gitRepoLeaf $gitRepoLeaf

    # Create a .lnk desktop shortcut to the local repo (opens in file explorer).
    CreateFileExplorerDesktopShortcut -gitLocalRepoLocation $GitLocalRepoLocation -gitRepoLeaf $gitRepoLeaf

    # all done. Let's return will exit code 0.
    return 0
}

catch
{
    if (($null -ne $Error[0]) -and ($null -ne $Error[0].Exception) -and ($null -ne $Error[0].Exception.Message))
    {
        $errMsg = $Error[0].Exception.Message
        WriteLog $errMsg
        Write-Host $errMsg
    }

    # Important note: Throwing a terminating error (using $ErrorActionPreference = "stop") still returns exit 
    # code zero from the powershell script. The workaround is to use try/catch blocks and return a non-zero 
    # exit code from the catch block. 
    return -1
}