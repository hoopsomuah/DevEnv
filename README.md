# DevEnv

A personal developer environment setup for Windows, including PowerShell configuration, Oh My Posh themes, and automated app installation via WinGet.

## Setup

### Quick Bootstrap (Recommended)

Run the following command in a PowerShell window to bootstrap the environment on a new machine:

```powershell
Invoke-WebRequest -Headers @{"Cache-Control"="no-cache"} -UseBasicParsing "https://raw.githubusercontent.com/hoopsomuah/DevEnv/refs/heads/main/bootstrap/bootstrap.ps1" | Invoke-Expression
```

This script will:
1. Detect or prompt you for a local path to clone the repo into (default: `~\src\DevEnv\`)
2. Clone the repository
3. Run `Configure-DevBox.ps1` to install apps and configure your PowerShell profile

> **Note:** `Configure-DevBox.ps1` must be run as **Administrator**.

### Manual Setup

If you already have the repository cloned locally:

1. Open PowerShell **as Administrator**
2. Run:
   ```powershell
   & "C:\path\to\DevEnv\bootstrap\Configure-DevBox.ps1"
   ```

This will:
- Set the PowerShell execution policy to `RemoteSigned`
- Install required PowerShell modules (`posh-git`, `PSReadLine`)
- Install minimum dev tools via WinGet (`winget\min-dev.dsc.yaml`)
- Optionally install additional dev apps (`winget\dev-plus.dsc.yaml`)
- Copy the PowerShell profile from `pwsh\profile.ps1` to your profile location

### Environment Variable

The scripts use the `pwsh_devenv` environment variable to locate the repository. It is set automatically by the bootstrap process. You can also set it manually:

```powershell
[Environment]::SetEnvironmentVariable("pwsh_devenv", "C:\path\to\DevEnv", "User")
```
