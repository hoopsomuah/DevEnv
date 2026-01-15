# DevEnv

A Windows development environment configuration toolkit that automates the setup of a new development machine using PowerShell scripts and WinGet DSC (Desired State Configuration).

## Overview

DevEnv provides:
- **Bootstrap scripts** for cloning and configuring this repository on a new machine
- **PowerShell profile** with custom drive aliases, Git utilities, and Oh-My-Posh integration
- **WinGet DSC configurations** for automated installation of development tools
- **Oh-My-Posh theme** for a customized terminal prompt

## Quick Start

Run the following command in an elevated PowerShell terminal to bootstrap a new machine:

```powershell
Invoke-WebRequest -Headers @{"Cache-Control"="no-cache"} -UseBasicParsing "https://raw.githubusercontent.com/hoopsomuah/DevEnv/master/bootstrap/bootstrap.ps1" | Invoke-Expression
```

## Repository Structure

```
DevEnv/
├── bootstrap/              # Bootstrap and configuration scripts
│   ├── bootstrap.ps1       # Web bootstrap script for new machines
│   ├── Clone-DevEnv.ps1    # Clone this repository to a local machine
│   └── Configure-DevBox.ps1# Configure development environment
├── pwsh/                   # PowerShell configuration
│   ├── profile.ps1         # PowerShell profile with custom settings
│   └── utilities.ps1       # Utility functions and aliases
├── ohmyposh/               # Oh-My-Posh terminal customization
│   └── hoop.omp.json       # Custom Oh-My-Posh theme
├── winget/                 # WinGet DSC configuration files
│   ├── min-dev.dsc.yaml    # Minimal development tools installation
│   └── dev-plus.dsc.yaml   # Extended development tools installation
├── backgrounds/            # Terminal background images
└── .vsconfig               # Visual Studio component configuration
```

## What Gets Installed

### Minimal Development Tools (`min-dev.dsc.yaml`)
- Git
- Visual Studio Code Insiders
- PowerShell
- Node.js
- Yarn
- Oh-My-Posh
- .NET SDK 7 and Preview
- Microsoft OpenJDK 17
- Sysinternals (Process Monitor and Process Explorer)

### Extended Development Tools (`dev-plus.dsc.yaml`)
- GitHub Desktop
- Microsoft Dev Home
- PowerToys
- Visual Studio 2022 Enterprise with workloads

## PowerShell Utilities

The profile includes several helpful utilities:

| Command/Alias | Description |
|---------------|-------------|
| `gfetch` | Recursively fetch all Git repositories in current directory |
| `gremote` | List remotes for all Git repositories in current directory |
| `codei` / `e` | Alias for VS Code Insiders |

### Drive Aliases

Custom PowerShell drives are created for quick navigation:
- `src:` - Points to `$HOME\src`
- `repos:` - Points to `$HOME\src\repos`
- `oss:` - Points to `$HOME\src\repos\oss`

## Configuration

### Environment Variable

Set `pwsh_devenv` to customize the DevEnv repository location:

```powershell
$env:pwsh_devenv = "C:\path\to\your\DevEnv"
[Environment]::SetEnvironmentVariable("pwsh_devenv", $env:pwsh_devenv, "User")
```

If not set, the default location is `$HOME\src\DevEnv\`.

## Requirements

- Windows 10 version 22000 or later (Windows 11)
- WinGet (Windows Package Manager)
- Administrator privileges for initial setup

## License

This project is provided as-is for personal development environment configuration.
