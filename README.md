## Automated Testing

This project uses [bats-core](https://github.com/bats-core/bats-core) for automated testing of bash scripts.

### Running Tests

1. bats-core is included as a git submodule in `test/bats-core`.
2. To run the tests, use:

  ```bash
  ./test/bats-core/bin/bats test/install.bats
  ```

3. Tests will run in a temporary directory and check for correct script behavior (e.g., CSV config creation, alias logging).

If you add new features or scripts, please add or update tests in the `test/` directory.
# dotfailes_v2

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

## Installation

### Prerequisites

**For Bash/Zsh scripts:**
- git
- jq (JSON processor)

**For PowerShell script:**
- git
- PowerShell 5.1+ or PowerShell Core 6+

### Install jq

**Linux (Debian/Ubuntu):**
```bash
sudo apt-get install jq
```

**MacOS:**
```bash
brew install jq
```

**Windows (Git Bash/MSYS2):**
```bash
pacman -S jq  # MSYS2
```

### Get the scripts

Clone this repository:

```bash
git clone https://github.com/lgallindo/dotfailes_v2.git
cd dotfailes_v2
```

#### Quick Installation (Linux/MacOS)

Use the installation script for an interactive setup:

```bash
./install.sh
```

The script will:
- Check prerequisites (git and jq)
- Detect your OS and select the appropriate script
- Guide you through repository initialization
- Optionally add the dotfiles alias to your shell configuration

#### Manual Installation

Or download individual scripts:
- `dotfailes.sh` - for Linux and general Unix systems
- `dotfailes.zsh` - for MacOS (zsh)
- `dotfailes.ps1` - for Windows (PowerShell/Git Bash/MSYS2)

## Quick Start

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

```bash
# Add files to track
dotfiles add ~/.bashrc
dotfiles add ~/.vimrc
dotfiles add ~/.gitconfig

# Commit changes
dotfiles commit -m "Add initial dotfiles"

# Set up a remote (optional)
dotfiles remote add origin https://github.com/yourusername/dotfiles.git
dotfiles push -u origin main
```

### 4. Clone on another machine

**Bash/Zsh:**
```bash
./dotfailes.sh clone https://github.com/yourusername/dotfiles.git ~/.dotfiles
```

**PowerShell:**
```powershell
.\dotfailes.ps1 clone https://github.com/yourusername/dotfiles.git C:\Users\username\.dotfiles
```

## Usage

### Commands

All scripts support the same commands:

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

```bash
# Add to your dotfiles repository
dotfiles add ~/.gitignore
```

Example `.gitignore`:
```
# Exclude sensitive files
.ssh/id_*
.ssh/*.pem
.gnupg/
.aws/credentials

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

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

Inspired by various dotfile management approaches and the bare git repository technique for tracking dotfiles without nested repositories.

## Support

For issues, questions, or suggestions, please open an issue on the GitHub repository.
