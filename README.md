# dots_v2

**Version 1.1.0**

[![Automated Tests](https://github.com/lgallindo/dotfailes_v2/actions/workflows/tests.yml/badge.svg)](https://github.com/lgallindo/dotfailes_v2/actions/workflows/tests.yml)

## Overview

**dots_v2** is a lightweight, high-integrity dotfile management system that uses **Bare Git Repositories** to track and synchronize configuration files across multiple environments. It is designed for maximum auditability, zero external dependencies (no `jq` required), and robust lifecycle management.

## Core Principles

1.  **Zero-Dependency**: No external tools required for daily use. Configuration is stored in pipe-delimited CSV (TOON format).
2.  **Audit-Ready**: Every action is logged with detailed metadata and row-count headers.
3.  **Safe-by-Default**: Robust rollback logic and `--purge` flags ensure the system remains clean.
4.  **Flexible Context**: Global `--setup` flag allows managing multiple environments from a single interface.

---

## Features

- ✨ **Bare Git Repository**: Track files in-place without nested `.git` folders.
- 📋 **CSV-Based Configuration**: Human-readable, grep-able, and `jq`-free config storage.
- 🔄 **Global Context Management**: Switch between setups using `--setup <name>`.
- 🛡️ **Lifecycle Safety**: Automatic rollback on failed `init` or `clone` operations.
- 📑 **Standardized Logging**: Detailed `config.log` and `rollback.log` with `[n|HEADER]` metadata.
- 🚀 **Automated Testing**: TDD-validated logic using `bats-core`.

<<<<<<< HEAD
## Logs and Process Documentation

The `install.sh` script automatically logs all configuration changes in the `logs/` directory:

- `logs/config.log`: Pipe-delimited configuration entries with metadata (timestamp, script, user, pwd, call args, version, key, value)
- `logs/rollback.log`: Pipe-delimited rollback instructions with revert commands

Each log file includes a header row describing the fields and a footer with total row count. Format:
```
# TIMESTAMP|SCRIPT|USER|PWD|CALL_ARGS|VERSION|KEY|VALUE
2026-02-04T13:35:18.280Z|install.sh|user|/path|args|1.0.0|CALL|
# TOTAL_ROWS: 5
```

Refer to these logs for installation history, troubleshooting, and rollback procedures. See `INSTALL_WORKFLOW.md` for detailed workflow documentation.

## Automated Testing

This project uses [bats-core](https://github.com/bats-core/bats-core) for automated testing of bash scripts.

### Install bats-core

bats-core is included as a git submodule. Initialize it with:

```bash
git submodule update --init --recursive
```

**Or**, install bats-core globally on your system:

**Linux (Debian/Ubuntu):**
```bash
sudo apt-get install bats
```

**Linux (Fedora/RHEL):**
```bash
sudo dnf install bats
```

**Linux (Arch):**
```bash
sudo pacman -S bats-core
```

**MacOS (Homebrew):**
```bash
brew install bats-core
```

**MacOS (MacPorts):**
```bash
sudo port install bats
```

**Windows (Git Bash/MSYS2):**
```bash
pacman -S bats
```

**From Source (all platforms):**
```bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

### Running Tests

If using the submodule:
```bash
./test/bats-core/bin/bats test/install.bats
```

If bats-core installed globally:
```bash
bats test/install.bats
```

Tests check for correct script behavior (e.g., pipe-delimited log creation, shell detection, alias logging).

If you add new features or scripts, please add or update tests in the `test/` directory.
# dotfailes_v2

**Version 1.0.0**

Dotfile management using bare git repositories with platform-specific scripts.

## Overview

**dotfailes_v2** is a lightweight, cross-platform dotfile management system that uses bare git repositories to track and synchronize your configuration files across multiple machines. It supports Linux, MacOS, and Windows with dedicated scripts for each platform.

## Features

- ✨ **Bare Git Repository**: Uses git's bare repository feature to track dotfiles without nested git repositories
- 🖥️ **Multi-Platform Support**: Dedicated scripts for bash (Linux/general), zsh (MacOS), and PowerShell (Windows/Git Bash/MSYS2)
- 📋 **Setup Management**: Track multiple setups with OS-specific configurations
- 🔄 **Remote Sync**: Easily push and pull changes from remote repositories
- 🎯 **Flexible**: Choose any directory as your dotfiles folder (default: home directory)
- 📦 **No Dependencies**: Only requires git and a JSON parser (jq for bash/zsh)
=======
---
>>>>>>> origin/feat/dots-remove-command

## Installation

### Prerequisites

- **Git**: Mandatory for version control.
- **Bash**: Required for `dots.sh` (Linux/WSL/MacOS).
- **PowerShell**: Required for `dots.ps1` (Windows).

> [!NOTE]
> `jq` is **optional**. It is only used for one-time automatic migration of old `.json` configurations to the new `.csv` format.

### Quick Install

```bash
git clone https://github.com/lgallindo/dotfailes_v2.git
cd dotfailes_v2
./install.sh
```

The interactive installer will:
1. Detect your OS and shell.
2. Initialize your first dotfile setup.
3. Configure your shell with the `dots` alias.

---

## CLI Usage

### Setup & Initialization

| Command | Usage | Description |
| :--- | :--- | :--- |
| `init` | `dots init <repo_path> [setup_name] [folder]` | Initialize a new bare repo. |
| `clone` | `dots clone <url> <repo_path> [setup_name] [folder]` | Clone an existing setup. |
| `rm` | `dots rm <setup_name> [--purge]` | Remove a setup from registry (purge deletes repo). |
| `list` | `dots list` | Dashboard of all registered setups. |

### Configuration Management

<<<<<<< HEAD
Or download individual scripts:
- `dotfailes.sh` - for Linux and general Unix systems
- `dotfailes.zsh` - for MacOS (zsh)
- `dotfailes.ps1` - for Windows (PowerShell/Git Bash/MSYS2)
=======
| Command | Usage | Description |
| :--- | :--- | :--- |
| `setup:show` | `dots setup:show` | Detailed info for the current/selected setup. |
| `registry:list` | `dots registry:list` | List known remote repository templates. |
| `registry:use` | `dots registry:use <name>` | Point the current setup to a registry remote. |
>>>>>>> origin/feat/dots-remove-command

### Daily Workflow (Git Proxy)

<<<<<<< HEAD
### 1. Initialize a new dotfile repository

**Bash/Zsh:**
```bash
./dotfailes.sh init ~/.dotfiles my-laptop ~/
```

**PowerShell:**
```powershell
.\dotfailes.ps1 init C:\Users\username\.dotfiles my-laptop C:\Users\username
```

### 2. Add an alias to your shell configuration

**Bash (~/.bashrc):**
```bash
alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
```

**Zsh (~/.zshrc):**
```zsh
alias dotfiles='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
```

**PowerShell (profile):**
```powershell
function dotfiles { git --git-dir="$HOME\.dotfiles" --work-tree="$HOME" @args }
```

### 3. Start tracking your dotfiles
=======
Commands like `add`, `commit`, `push`, `pull`, `diff`, `log`, and `status` are proxied directly to the bare git repository of the active setup.
>>>>>>> origin/feat/dots-remove-command

```bash
# Using the default setup
dots status
dots add .bashrc
dots commit -m "update bashrc"
dots push

# Target a specific setup
dots --setup work-laptop status
dots --setup server-prod pull
```

---

<<<<<<< HEAD
**Bash/Zsh:**
```bash
./dotfailes.sh clone https://github.com/yourusername/dotfiles.git ~/.dotfiles
```

**PowerShell:**
```powershell
.\dotfailes.ps1 clone https://github.com/yourusername/dotfiles.git C:\Users\username\.dotfiles
```
=======
## Logging & Auditability

All operations are recorded in the `~/.dotfailes/logs/` directory using the **TOON** (Tab/CSV Organized Object Notation) format.
>>>>>>> origin/feat/dots-remove-command

### Log Format `[n|HEADER]`
Files start with a metadata header containing the row count and field names:
`[5|TIMESTAMP|SCRIPT|USER|PWD|CALL|VERSION|KEY|VALUE]`

Refer to [PARSEABILITY.md](PARSEABILITY.md) for examples on how to query logs and configs using `grep`, `awk`, or PowerShell.

---

<<<<<<< HEAD
#### Initialize a new repository
```bash
dotfailes.sh init <repo_path> [setup_name] [dotfiles_folder]
```
- `repo_path`: Path where the bare git repository will be stored
- `setup_name`: (optional) Name for this setup (defaults to hostname-OS)
- `dotfiles_folder`: (optional) Directory to track (defaults to home directory)

#### Clone an existing repository
```bash
dotfailes.sh clone <remote_url> <repo_path> [setup_name] [dotfiles_folder]
```
- `remote_url`: Git remote URL to clone from
- `repo_path`: Local path for the bare repository
- `setup_name`: (optional) Name for this setup
- `dotfiles_folder`: (optional) Directory to track

#### List configured setups
```bash
dotfailes.sh list
```
Shows all registered setups with their OS, folder, and repository paths.

#### List bash files for a setup
```bash
dotfailes.sh bash:list [setup_name]
```
Lists bash-related files (.bashrc, .bash_profile, .bash_aliases, .bashrc.d) and whether they exist locally and are tracked in the setup branch.

#### Reload bash files for a setup
```bash
dotfailes.sh bash:reload [setup_name]
```
Reloads bash-related files from the remote setup branch without creating backups.

#### Add a remote
```bash
dotfailes.sh add-remote <setup_name> <remote_name> <remote_url>
```
Add a git remote to a setup (e.g., origin, backup, etc.).

#### List remotes
```bash
dotfailes.sh list-remotes <setup_name>
```
Show all remotes configured for a setup.

#### List registered dotfiles repositories
```bash
dotfailes.sh registry:list
```
Show all registered repositories with their URLs and descriptions.

#### Use a registered repository for a setup
```bash
dotfailes.sh registry:use <registry_name> [setup_name] [remote_name]
```
Sets or updates the setup's remote (default: origin) to the selected registry URL.

#### Remove a remote
```bash
dotfailes.sh remove-remote <setup_name> <remote_name>
```
Remove a git remote from a setup.

#### Sync with remote
```bash
dotfailes.sh sync <setup_name> [remote_name] [branch]
```
Pull and push changes to/from remote. Defaults: remote=origin, branch=main.

#### Check status
```bash
dotfailes.sh status <setup_name>
```
Show git status for a setup (tracked/untracked files, changes, etc.).

#### Get help
```bash
dotfailes.sh help
```

## Configuration

### Configuration File

The scripts store setup information in a JSON configuration file:
- **Linux/MacOS**: `~/.dotfailes/config.json`
- **Windows**: `%USERPROFILE%\.dotfailes\config.json`

### Configuration Structure

```json
{
  "setups": [
    {
      "name": "my-laptop-Linux",
      "os": "Linux",
      "folder": "/home/username",
      "repo": "/home/username/.dotfiles"
    },
    {
      "name": "my-desktop-Windows",
      "os": "Windows",
      "folder": "C:\\Users\\username",
      "repo": "C:\\Users\\username\\.dotfiles"
    }
  ]
}
```

Each setup tracks:
- **name**: Identifier for the setup
- **os**: Operating system (Linux, MacOS, Windows)
- **folder**: The work tree (where your dotfiles live)
- **repo**: The bare git repository location

## Best Practices

### Recommended Dotfiles to Track

**Linux/Unix:**
- `~/.bashrc`, `~/.bash_profile`
- `~/.zshrc`, `~/.zprofile`
- `~/.vimrc`, `~/.vim/`
- `~/.gitconfig`
- `~/.tmux.conf`
- `~/.ssh/config` (be careful with sensitive files!)

**MacOS:**
- All Linux/Unix files plus:
- `~/.zshenv`, `~/.zlogin`
- Application preferences from `~/Library/`

**Windows (PowerShell):**
- PowerShell profile: `$PROFILE` (usually `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`)
- Git config: `.gitconfig`
- SSH config: `.ssh\config`
- Windows Terminal settings

### Security Considerations

⚠️ **Important**: Be careful not to track sensitive information such as:
- Private SSH keys (track `~/.ssh/config` but NOT `~/.ssh/id_rsa`)
- API tokens and passwords
- Private credentials

Use `.gitignore` in your dotfiles repository to exclude sensitive files.

### Ignoring Files

Create a `.gitignore` in your home directory (or dotfiles folder) to exclude files you don't want to track:
=======
## Advanced: Bare Git Repository Manual Usage

If you prefer using git directly, the `install.sh` script creates an alias like this:
>>>>>>> origin/feat/dots-remove-command

```bash
alias dots='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
```

This allows you to manage your dotfiles exactly like any other git repository without moving them into a specific folder.

<<<<<<< HEAD
# Exclude cache and temporary files
.cache/
.local/
*.log
```

## Advanced Usage

### Using the dotfiles alias

Once you've set up the alias, use it like a regular git command:

```bash
# Check status
dotfiles status

# Add files
dotfiles add ~/.config/nvim/init.vim

# Commit
dotfiles commit -m "Update neovim config"

# Push to remote
dotfiles push

# Pull from remote
dotfiles pull

# View history
dotfiles log --oneline

# See differences
dotfiles diff
```

### Managing Multiple Setups

You can manage different setups on the same machine (e.g., work and personal):

```bash
# Initialize work setup
./dotfailes.sh init ~/.dotfiles-work work-setup ~/work

# Initialize personal setup
./dotfailes.sh init ~/.dotfiles-personal personal-setup ~/

# Create separate aliases
alias dotfiles-work='git --git-dir=$HOME/.dotfiles-work --work-tree=$HOME/work'
alias dotfiles='git --git-dir=$HOME/.dotfiles-personal --work-tree=$HOME'
```

### Setting Up on a New Machine

1. Clone the repository
2. Set up the alias
3. Check out your files:

```bash
# After cloning
dotfiles checkout

# If there are conflicts, back up existing files
mkdir -p .config-backup
dotfiles checkout 2>&1 | grep -E "^\s+" | awk {'print $1'} | xargs -I{} mv {} .config-backup/{}

# Try checkout again
dotfiles checkout

# Hide untracked files
dotfiles config --local status.showUntrackedFiles no
```

## Platform-Specific Notes

### Windows with Git Bash/MSYS2

The PowerShell script is designed to work in:
- Native PowerShell (Windows PowerShell 5.1+)
- PowerShell Core (pwsh 6+)
- Git Bash (can run bash script)
- MSYS2 (can run bash script)

PowerShell profiles are automatically considered dotfiles. Common locations:
- Current User, Current Host: `$PROFILE`
- Current User, All Hosts: `$PROFILE.CurrentUserAllHosts`

### MacOS with Zsh

The zsh script is optimized for MacOS's default zsh shell. Common zsh configuration files:
- `~/.zshrc` - Main configuration
- `~/.zshenv` - Environment variables
- `~/.zprofile` - Login shell configuration
- `~/.zlogin` - Login commands
- `~/.zlogout` - Logout commands

## Troubleshooting

### "command not found: jq"
Install jq using your package manager (see Installation section).

### Untracked files showing up
Configure git to hide untracked files:
```bash
dotfiles config --local status.showUntrackedFiles no
```

### Conflicts when checking out
Back up conflicting files before checking out:
```bash
mkdir -p ~/.config-backup
# Move conflicting files to backup directory
dotfiles checkout
```

### Permission issues on scripts
Make scripts executable:
```bash
chmod +x dotfailes.sh dotfailes.zsh
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
=======
---

## Troubleshooting

- **"Setup not found"**: Ensure you have run `dots init` or `dots clone`. Check `~/.dotfailes/config.csv`.
- **Conflicts on Checkout**: If files already exist, move them to a backup folder before checking out:
  `dots checkout 2>&1 | grep -E "^\s+" | awk {'print $1'} | xargs -I{} mv {} ~/.dotfiles-backup/{}`
>>>>>>> origin/feat/dots-remove-command

## License

This project is licensed under the GNU General Public License v3.0.

---

## Acknowledgments

Inspired by the "bare git repository" technique for dotfile management. Standardized for high-compliance and multi-setup environments.
