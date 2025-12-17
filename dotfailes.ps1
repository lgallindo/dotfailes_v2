#!/usr/bin/env pwsh
# dotfailes - Dotfile management using bare git repositories
# Copyright (C) 2025
# Licensed under GNU General Public License v3.0

$ErrorActionPreference = "Stop"

# Default configuration
$script:HomeDir = if ($env:USERPROFILE) { $env:USERPROFILE } else { $env:HOME }
$script:DefaultDotfilesDir = Join-Path $script:HomeDir ".dotfailes"
$script:DotfilesDir = if ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { $script:DefaultDotfilesDir }
$script:ConfigFile = Join-Path $script:DotfilesDir "config.json"

# Helper functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Stop-WithError {
    param([string]$Message)
    Write-ErrorMsg $Message
    exit 1
}

# Initialize configuration file
function Initialize-Config {
    if (-not (Test-Path $script:ConfigFile)) {
        $configDir = Split-Path $script:ConfigFile -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        $config = @{
            setups = @()
        }
        $config | ConvertTo-Json | Set-Content $script:ConfigFile
        Write-Success "Configuration file created at $($script:ConfigFile)"
    }
}

# Get OS type
function Get-OSType {
    if ($IsWindows -or $env:OS -eq "Windows_NT") {
        return "Windows"
    } elseif ($IsMacOS) {
        return "MacOS"
    } elseif ($IsLinux) {
        return "Linux"
    } else {
        return "Unknown"
    }
}

# Initialize bare git repository
function Invoke-Init {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RepoPath,
        [string]$SetupName,
        [string]$DotfilesFolder
    )
    
    if (-not $SetupName) {
        $hostname = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { hostname }
        $SetupName = "$hostname-$(Get-OSType)"
    }
    
    if (-not $DotfilesFolder) {
        $DotfilesFolder = $script:HomeDir
    }
    
    # Create bare repository
    if (Test-Path $RepoPath) {
        Write-Warning "Repository path already exists: $RepoPath"
        $response = Read-Host "Do you want to continue? (y/n)"
        if ($response -ne 'y' -and $response -ne 'Y') {
            Stop-WithError "Initialization cancelled"
        }
    }
    
    if (-not (Test-Path $RepoPath)) {
        New-Item -ItemType Directory -Path $RepoPath -Force | Out-Null
    }
    
    git init --bare $RepoPath
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError "Failed to initialize git repository"
    }
    
    Write-Success "Bare git repository initialized at $RepoPath"
    
    # Add to configuration
    Initialize-Config
    $osType = Get-OSType
    
    $config = Get-Content $script:ConfigFile | ConvertFrom-Json
    $setup = @{
        name = $SetupName
        os = $osType
        folder = $DotfilesFolder
        repo = $RepoPath
    }
    $config.setups += $setup
    $config | ConvertTo-Json | Set-Content $script:ConfigFile
    
    Write-Success "Setup '$SetupName' registered (OS: $osType, Folder: $DotfilesFolder)"
    
    # Create alias helper
    Write-Info "To use this dotfile repository, add this function to your PowerShell profile:"
    Write-Host ""
    Write-Host "    function dotfiles { git --git-dir='$RepoPath' --work-tree='$DotfilesFolder' @args }"
    Write-Host ""
}

# Clone existing bare repository
function Invoke-Clone {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RemoteUrl,
        [Parameter(Mandatory=$true)]
        [string]$RepoPath,
        [string]$SetupName,
        [string]$DotfilesFolder
    )
    
    if (-not $SetupName) {
        $hostname = if ($env:COMPUTERNAME) { $env:COMPUTERNAME } else { hostname }
        $SetupName = "$hostname-$(Get-OSType)"
    }
    
    if (-not $DotfilesFolder) {
        $DotfilesFolder = $script:HomeDir
    }
    
    # Clone as bare repository
    git clone --bare $RemoteUrl $RepoPath
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError "Failed to clone repository"
    }
    
    Write-Success "Repository cloned to $RepoPath"
    
    # Add to configuration
    Initialize-Config
    $osType = Get-OSType
    
    $config = Get-Content $script:ConfigFile | ConvertFrom-Json
    $setup = @{
        name = $SetupName
        os = $osType
        folder = $DotfilesFolder
        repo = $RepoPath
    }
    $config.setups += $setup
    $config | ConvertTo-Json | Set-Content $script:ConfigFile
    
    Write-Success "Setup '$SetupName' registered"
    
    # Create alias helper
    Write-Info "To use this dotfile repository, add this function to your PowerShell profile:"
    Write-Host ""
    Write-Host "    function dotfiles { git --git-dir='$RepoPath' --work-tree='$DotfilesFolder' @args }"
    Write-Host ""
}

# List all configured setups
function Invoke-List {
    Initialize-Config
    
    $config = Get-Content $script:ConfigFile | ConvertFrom-Json
    
    if ($config.setups.Count -eq 0) {
        Write-Warning "No setups configured yet"
        return
    }
    
    Write-Info "Configured setups:"
    Write-Host ""
    foreach ($setup in $config.setups) {
        Write-Host "  • $($setup.name)"
        Write-Host "    OS: $($setup.os)"
        Write-Host "    Folder: $($setup.folder)"
        Write-Host "    Repo: $($setup.repo)"
        Write-Host ""
    }
}

# Add remote to a setup
function Invoke-AddRemote {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SetupName,
        [Parameter(Mandatory=$true)]
        [string]$RemoteName,
        [Parameter(Mandatory=$true)]
        [string]$RemoteUrl
    )
    
    Initialize-Config
    
    $config = Get-Content $script:ConfigFile | ConvertFrom-Json
    $setup = $config.setups | Where-Object { $_.name -eq $SetupName }
    
    if (-not $setup) {
        Stop-WithError "Setup '$SetupName' not found"
    }
    
    $repoPath = $setup.repo
    
    # Add remote
    git --git-dir=$repoPath remote add $RemoteName $RemoteUrl 2>$null
    if ($LASTEXITCODE -ne 0) {
        git --git-dir=$repoPath remote set-url $RemoteName $RemoteUrl
    }
    
    Write-Success "Remote '$RemoteName' added to setup '$SetupName'"
}

# List remotes for a setup
function Invoke-ListRemotes {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SetupName
    )
    
    Initialize-Config
    
    $config = Get-Content $script:ConfigFile | ConvertFrom-Json
    $setup = $config.setups | Where-Object { $_.name -eq $SetupName }
    
    if (-not $setup) {
        Stop-WithError "Setup '$SetupName' not found"
    }
    
    Write-Info "Remotes for setup '$SetupName':"
    git --git-dir=$setup.repo remote -v
}

# Remove remote from a setup
function Invoke-RemoveRemote {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SetupName,
        [Parameter(Mandatory=$true)]
        [string]$RemoteName
    )
    
    Initialize-Config
    
    $config = Get-Content $script:ConfigFile | ConvertFrom-Json
    $setup = $config.setups | Where-Object { $_.name -eq $SetupName }
    
    if (-not $setup) {
        Stop-WithError "Setup '$SetupName' not found"
    }
    
    git --git-dir=$setup.repo remote remove $RemoteName
    if ($LASTEXITCODE -ne 0) {
        Stop-WithError "Failed to remove remote"
    }
    
    Write-Success "Remote '$RemoteName' removed from setup '$SetupName'"
}

# Sync with remote
function Invoke-Sync {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SetupName,
        [string]$RemoteName = "origin",
        [string]$Branch = "main"
    )
    
    Initialize-Config
    
    $config = Get-Content $script:ConfigFile | ConvertFrom-Json
    $setup = $config.setups | Where-Object { $_.name -eq $SetupName }
    
    if (-not $setup) {
        Stop-WithError "Setup '$SetupName' not found"
    }
    
    $repoPath = $setup.repo
    $workTree = $setup.folder
    
    Write-Info "Syncing setup '$SetupName' with remote '$RemoteName'..."
    
    # Pull changes
    Write-Info "Pulling changes from $RemoteName/$Branch..."
    git --git-dir=$repoPath --work-tree=$workTree pull $RemoteName $Branch
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Pull failed or no changes"
    }
    
    # Push changes
    Write-Info "Pushing changes to $RemoteName/$Branch..."
    git --git-dir=$repoPath --work-tree=$workTree push $RemoteName $Branch
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Push failed or no changes"
    }
    
    Write-Success "Sync completed"
}

# Show status for a setup
function Invoke-Status {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SetupName
    )
    
    Initialize-Config
    
    $config = Get-Content $script:ConfigFile | ConvertFrom-Json
    $setup = $config.setups | Where-Object { $_.name -eq $SetupName }
    
    if (-not $setup) {
        Stop-WithError "Setup '$SetupName' not found"
    }
    
    Write-Info "Status for setup '$SetupName':"
    git --git-dir=$setup.repo --work-tree=$setup.folder status
}

# Show help
function Show-Help {
    @"
dotfailes - Dotfile management using bare git repositories

USAGE:
    .\dotfailes.ps1 <command> [arguments]

COMMANDS:
    init <repo_path> [setup_name] [dotfiles_folder]
        Initialize a new bare git repository for dotfile management
        
    clone <remote_url> <repo_path> [setup_name] [dotfiles_folder]
        Clone an existing dotfile repository
        
    list
        List all configured setups
        
    add-remote <setup_name> <remote_name> <remote_url>
        Add a remote to a setup
        
    list-remotes <setup_name>
        List remotes for a setup
        
    remove-remote <setup_name> <remote_name>
        Remove a remote from a setup
        
    sync <setup_name> [remote_name] [branch]
        Sync with remote (pull and push)
        Default remote: origin, Default branch: main
        
    status <setup_name>
        Show git status for a setup
        
    help
        Show this help message

EXAMPLES:
    # Initialize new dotfile repository
    .\dotfailes.ps1 init C:\Users\username\.dotfiles my-laptop C:\Users\username
    
    # Clone existing dotfile repository
    .\dotfailes.ps1 clone https://github.com/user/dotfiles.git C:\Users\username\.dotfiles
    
    # Add a remote
    .\dotfailes.ps1 add-remote my-laptop origin https://github.com/user/dotfiles.git
    
    # Sync with remote
    .\dotfailes.ps1 sync my-laptop origin main
    
    # Check status
    .\dotfailes.ps1 status my-laptop

CONFIGURATION:
    Configuration is stored in: $($script:ConfigFile)
    
    Each setup tracks:
    - Setup name
    - Operating system
    - Dotfiles folder (work tree)
    - Repository path (bare git repo)

POWERSHELL PROFILES:
    PowerShell profiles are automatically considered as dotfiles.
    Common profile locations:
    - Current User, Current Host: `$PROFILE`
    - Current User, All Hosts: `$PROFILE.CurrentUserAllHosts`
    - All Users, Current Host: `$PROFILE.AllUsersCurrentHost`
    - All Users, All Hosts: `$PROFILE.AllUsersAllHosts`

"@
}

# Main command dispatcher
function Main {
    param([string[]]$Arguments)
    
    if ($Arguments.Count -eq 0) {
        Show-Help
        return
    }
    
    $command = $Arguments[0]
    $cmdArgs = $Arguments[1..($Arguments.Count - 1)]
    
    switch ($command) {
        "init" {
            if ($cmdArgs.Count -lt 1) {
                Stop-WithError "Usage: init <repo_path> [setup_name] [dotfiles_folder]"
            }
            Invoke-Init -RepoPath $cmdArgs[0] -SetupName $cmdArgs[1] -DotfilesFolder $cmdArgs[2]
        }
        "clone" {
            if ($cmdArgs.Count -lt 2) {
                Stop-WithError "Usage: clone <remote_url> <repo_path> [setup_name] [dotfiles_folder]"
            }
            Invoke-Clone -RemoteUrl $cmdArgs[0] -RepoPath $cmdArgs[1] -SetupName $cmdArgs[2] -DotfilesFolder $cmdArgs[3]
        }
        "list" {
            Invoke-List
        }
        "add-remote" {
            if ($cmdArgs.Count -lt 3) {
                Stop-WithError "Usage: add-remote <setup_name> <remote_name> <remote_url>"
            }
            Invoke-AddRemote -SetupName $cmdArgs[0] -RemoteName $cmdArgs[1] -RemoteUrl $cmdArgs[2]
        }
        "list-remotes" {
            if ($cmdArgs.Count -lt 1) {
                Stop-WithError "Usage: list-remotes <setup_name>"
            }
            Invoke-ListRemotes -SetupName $cmdArgs[0]
        }
        "remove-remote" {
            if ($cmdArgs.Count -lt 2) {
                Stop-WithError "Usage: remove-remote <setup_name> <remote_name>"
            }
            Invoke-RemoveRemote -SetupName $cmdArgs[0] -RemoteName $cmdArgs[1]
        }
        "sync" {
            if ($cmdArgs.Count -lt 1) {
                Stop-WithError "Usage: sync <setup_name> [remote_name] [branch]"
            }
            Invoke-Sync -SetupName $cmdArgs[0] -RemoteName $cmdArgs[1] -Branch $cmdArgs[2]
        }
        "status" {
            if ($cmdArgs.Count -lt 1) {
                Stop-WithError "Usage: status <setup_name>"
            }
            Invoke-Status -SetupName $cmdArgs[0]
        }
        { $_ -in "help", "--help", "-h" } {
            Show-Help
        }
        default {
            Write-ErrorMsg "Unknown command: $command"
            Write-Host ""
            Show-Help
            exit 1
        }
    }
}

# Run main function
Main $args
