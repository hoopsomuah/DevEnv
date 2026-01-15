# GitHub Copilot Agents

This document describes how GitHub Copilot agents can assist with developing and maintaining this DevEnv repository.

## Overview

GitHub Copilot agents are specialized AI assistants that can help with various development tasks. This repository can benefit from agents in several ways:

## Use Cases

### PowerShell Script Development

Agents can assist with:
- Writing and debugging PowerShell scripts in the `bootstrap/` and `pwsh/` directories
- Creating new utility functions in `utilities.ps1`
- Improving error handling and validation logic
- Optimizing script performance

### WinGet DSC Configuration

Agents can help with:
- Adding new package installations to `winget/*.dsc.yaml` files
- Configuring additional Windows settings through DSC resources
- Validating YAML schema compliance
- Finding correct WinGet package IDs for new tools

### Oh-My-Posh Theme Customization

Agents can assist with:
- Modifying the `ohmyposh/hoop.omp.json` theme
- Adding new prompt segments
- Customizing colors and icons
- Troubleshooting theme rendering issues

### Documentation

Agents can help maintain:
- This README and documentation files
- Inline code comments
- Script synopsis and parameter documentation

## Example Prompts

Here are some example prompts for working with this repository:

- "Add a new utility function to check if a Git repository has uncommitted changes"
- "Update the min-dev.dsc.yaml to include Docker Desktop"
- "Improve the error messages in bootstrap.ps1 to be more user-friendly"
- "Add a new drive alias for my projects folder"

## Best Practices

When using Copilot agents with this repository:

1. **Test changes locally** - Always test PowerShell scripts on a Windows machine before committing
2. **Verify package IDs** - Confirm WinGet package IDs exist using `winget search`
3. **Backup existing config** - The scripts already backup profiles; follow the same pattern for new files
4. **Document changes** - Keep this documentation updated when adding new features
