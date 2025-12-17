# Examples

This document provides practical examples of using dotfailes for various scenarios.

## Table of Contents

- [Basic Setup](#basic-setup)
- [Working with Dotfiles](#working-with-dotfiles)
- [Multi-Machine Setup](#multi-machine-setup)
- [Platform-Specific Examples](#platform-specific-examples)
- [Common Workflows](#common-workflows)

## Basic Setup

### First-Time Setup on Linux

```bash
# 1. Initialize your dotfile repository
./dotfailes.sh init ~/.dotfiles my-laptop ~/

# 2. Add the alias to your .bashrc
echo "alias dotfiles='git --git-dir=\$HOME/.dotfiles --work-tree=\$HOME'" >> ~/.bashrc
source ~/.bashrc

# 3. Configure git to hide untracked files
dotfiles config --local status.showUntrackedFiles no

# 4. Add your first dotfiles
dotfiles add ~/.bashrc
dotfiles add ~/.vimrc
dotfiles add ~/.gitconfig

# 5. Commit
dotfiles commit -m "Initial commit: bashrc, vimrc, gitconfig"

# 6. (Optional) Push to remote
dotfiles remote add origin https://github.com/yourusername/dotfiles.git
dotfiles push -u origin main
```

### First-Time Setup on MacOS

```zsh
# 1. Initialize your dotfile repository
./dotfailes.zsh init ~/.dotfiles my-macbook ~/

# 2. Add the alias to your .zshrc
echo "alias dotfiles='git --git-dir=\$HOME/.dotfiles --work-tree=\$HOME'" >> ~/.zshrc
source ~/.zshrc

# 3. Configure git to hide untracked files
dotfiles config --local status.showUntrackedFiles no

# 4. Add your zsh configuration
dotfiles add ~/.zshrc
dotfiles add ~/.zshenv
dotfiles add ~/.gitconfig

# 5. Commit
dotfiles commit -m "Initial commit: zsh configuration"
```

### First-Time Setup on Windows (PowerShell)

```powershell
# 1. Initialize your dotfile repository
.\dotfailes.ps1 init C:\Users\username\.dotfiles my-windows C:\Users\username

# 2. Add the function to your PowerShell profile
# First, create profile if it doesn't exist
if (!(Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -ItemType File -Force
}

# Add the function
Add-Content $PROFILE "function dotfiles { git --git-dir='C:\Users\username\.dotfiles' --work-tree='C:\Users\username' @args }"

# Reload profile
. $PROFILE

# 3. Configure git to hide untracked files
dotfiles config --local status.showUntrackedFiles no

# 4. Add PowerShell profile and git config
dotfiles add $PROFILE
dotfiles add .gitconfig

# 5. Commit
dotfiles commit -m "Initial commit: PowerShell profile"
```

## Working with Dotfiles

### Adding New Files

```bash
# Add a single file
dotfiles add ~/.tmux.conf

# Add a directory
dotfiles add ~/.config/nvim

# Check what will be committed
dotfiles status

# Commit changes
dotfiles commit -m "Add tmux and neovim configuration"
```

### Updating Files

```bash
# Make changes to your dotfiles
vim ~/.vimrc

# Check what changed
dotfiles diff

# Commit the changes
dotfiles add ~/.vimrc
dotfiles commit -m "Update vimrc: add new plugins"

# Push to remote
dotfiles push
```

### Ignoring Files

Create a `.gitignore` in your home directory:

```bash
# Add .gitignore to your dotfiles
cat > ~/.gitignore << 'EOF'
# Exclude sensitive files
.ssh/id_*
.ssh/*.pem
.gnupg/
.aws/credentials

# Exclude cache directories
.cache/
.local/share/
.npm/
.cargo/

# Exclude logs
*.log

# Exclude temporary files
*~
.*.swp
EOF

# Track the .gitignore file
dotfiles add ~/.gitignore
dotfiles commit -m "Add gitignore for sensitive and temporary files"
```

## Multi-Machine Setup

### Setting Up Second Machine from Remote

```bash
# 1. Clone your dotfiles
./dotfailes.sh clone https://github.com/yourusername/dotfiles.git ~/.dotfiles work-desktop ~/

# 2. Add alias to shell config
echo "alias dotfiles='git --git-dir=\$HOME/.dotfiles --work-tree=\$HOME'" >> ~/.bashrc
source ~/.bashrc

# 3. Checkout your dotfiles (backup any conflicts first)
mkdir -p ~/.config-backup

# Move any conflicting files to backup
dotfiles checkout 2>&1 | grep -E "^\s+" | awk {'print $1'} | \
    xargs -I{} sh -c 'mkdir -p ~/.config-backup/$(dirname {}) && mv {} ~/.config-backup/{}'

# Try checkout again
dotfiles checkout

# 4. Configure git
dotfiles config --local status.showUntrackedFiles no

# 5. Check status
dotfiles status
```

### Syncing Between Machines

On machine A (after making changes):
```bash
dotfiles add ~/.vimrc
dotfiles commit -m "Update vimrc"
dotfiles push
```

On machine B (to get updates):
```bash
dotfiles pull
```

### Managing Multiple Setups

You can manage work and personal dotfiles separately:

```bash
# Initialize work setup
./dotfailes.sh init ~/.dotfiles-work work-setup ~/work
echo "alias dotfiles-work='git --git-dir=\$HOME/.dotfiles-work --work-tree=\$HOME/work'" >> ~/.bashrc

# Initialize personal setup
./dotfailes.sh init ~/.dotfiles-personal personal-setup ~/
echo "alias dotfiles='git --git-dir=\$HOME/.dotfiles-personal --work-tree=\$HOME'" >> ~/.bashrc

# Reload config
source ~/.bashrc

# Now you can use both
dotfiles status          # Personal dotfiles
dotfiles-work status     # Work dotfiles
```

## Platform-Specific Examples

### Linux: Managing System Configuration

```bash
# Add shell configurations
dotfiles add ~/.bashrc
dotfiles add ~/.bash_profile
dotfiles add ~/.profile

# Add vim configuration
dotfiles add ~/.vimrc
dotfiles add ~/.vim/

# Add tmux configuration
dotfiles add ~/.tmux.conf

# Add git configuration
dotfiles add ~/.gitconfig

# Add SSH configuration (but not keys!)
dotfiles add ~/.ssh/config

# Commit everything
dotfiles commit -m "Add Linux system configuration"
```

### MacOS: Managing Application Preferences

```zsh
# Add shell configurations
dotfiles add ~/.zshrc
dotfiles add ~/.zshenv
dotfiles add ~/.zprofile

# Add Homebrew bundle file
dotfiles add ~/.Brewfile

# Add application preferences (be selective)
dotfiles add ~/Library/Application\ Support/Code/User/settings.json

# Commit
dotfiles commit -m "Add MacOS application preferences"
```

### Windows: Managing PowerShell and Tools

```powershell
# Add PowerShell profiles
dotfiles add $PROFILE.CurrentUserCurrentHost
dotfiles add $PROFILE.CurrentUserAllHosts

# Add Windows Terminal settings
$wtSettings = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
dotfiles add $wtSettings

# Add git configuration
dotfiles add .gitconfig

# Add SSH config
dotfiles add .ssh\config

# Commit
dotfiles commit -m "Add Windows PowerShell and tool configurations"
```

## Common Workflows

### Creating a Portable Development Environment

```bash
# 1. Track your editor configuration
dotfiles add ~/.vimrc
dotfiles add ~/.config/nvim/

# 2. Track your shell configuration
dotfiles add ~/.bashrc
dotfiles add ~/.bash_aliases

# 3. Track your git configuration
dotfiles add ~/.gitconfig

# 4. Track development tool configurations
dotfiles add ~/.tmux.conf
dotfiles add ~/.screenrc

# 5. Create a setup script for new machines
cat > ~/setup.sh << 'EOF'
#!/bin/bash
# Install essential tools
sudo apt-get update
sudo apt-get install -y vim git tmux build-essential

# Clone dotfiles
git clone --bare https://github.com/yourusername/dotfiles.git ~/.dotfiles
git --git-dir=$HOME/.dotfiles --work-tree=$HOME checkout -f

# Add alias
echo "alias dotfiles='git --git-dir=\$HOME/.dotfiles --work-tree=\$HOME'" >> ~/.bashrc
source ~/.bashrc

# Configure git
dotfiles config --local status.showUntrackedFiles no
EOF

# Track the setup script
dotfiles add ~/setup.sh
dotfiles commit -m "Add portable development environment setup"
```

### Sharing Configuration with Team

```bash
# Create a team-shared configuration
./dotfailes.sh init ~/.dotfiles-team team-config ~/team-workspace

# Add team alias
echo "alias team-dotfiles='git --git-dir=\$HOME/.dotfiles-team --work-tree=\$HOME/team-workspace'" >> ~/.bashrc
source ~/.bashrc

# Add team-specific configurations
team-dotfiles add ~/team-workspace/.editorconfig
team-dotfiles add ~/team-workspace/.eslintrc
team-dotfiles add ~/team-workspace/.prettierrc

# Commit and push to shared repository
team-dotfiles commit -m "Add team code style configuration"
team-dotfiles remote add origin https://github.com/company/team-dotfiles.git
team-dotfiles push -u origin main
```

### Backing Up Before Major Changes

```bash
# Create a backup branch
dotfiles checkout -b backup-before-update

# Make your changes
vim ~/.bashrc
dotfiles add ~/.bashrc
dotfiles commit -m "Experiment with new bashrc configuration"

# If something goes wrong, restore from backup
dotfiles checkout main
dotfiles reset --hard HEAD

# If everything works, merge the changes
dotfiles checkout main
dotfiles merge backup-before-update
```

### Managing Secrets Safely

```bash
# Never track actual secrets! Use a template instead
cat > ~/.aws/credentials.template << 'EOF'
[default]
aws_access_key_id = YOUR_ACCESS_KEY_HERE
aws_secret_access_key = YOUR_SECRET_KEY_HERE
EOF

# Track the template, not the real file
dotfiles add ~/.aws/credentials.template
dotfiles commit -m "Add AWS credentials template"

# Make sure real credentials are ignored
echo ".aws/credentials" >> ~/.gitignore
dotfiles add ~/.gitignore
dotfiles commit -m "Ignore AWS credentials file"
```

### Migrating from Old Dotfile System

```bash
# If you have an old git repo in ~/dotfiles
cd ~/dotfiles

# Export all files
git archive main | tar -x -C /tmp/old-dotfiles

# Initialize new bare repo
./dotfailes.sh init ~/.dotfiles my-laptop ~/

# Add the alias
echo "alias dotfiles='git --git-dir=\$HOME/.dotfiles --work-tree=\$HOME'" >> ~/.bashrc
source ~/.bashrc

# Copy files to home directory
cp -r /tmp/old-dotfiles/.* ~/

# Add files to new system
cd ~
dotfiles add .bashrc .vimrc .gitconfig
dotfiles commit -m "Migrate from old dotfile system"

# Remove old dotfiles directory
rm -rf ~/dotfiles /tmp/old-dotfiles
```

## Tips and Tricks

### Quick Status Check

Create a function to quickly check dotfile status:

```bash
# Add to .bashrc
dotfiles-check() {
    echo "=== Dotfiles Status ==="
    dotfiles status
    echo ""
    echo "=== Unpushed Commits ==="
    dotfiles log origin/main..HEAD --oneline
}
```

### Automatic Sync on Shell Exit

```bash
# Add to .bash_logout
dotfiles add -u && dotfiles commit -m "Auto-commit on logout" && dotfiles push
```

### Platform Detection for Conditional Configuration

```bash
# In your .bashrc
if [[ "$(uname)" == "Darwin" ]]; then
    # MacOS-specific configuration
    export HOMEBREW_PREFIX="/opt/homebrew"
elif [[ "$(uname)" == "Linux" ]]; then
    # Linux-specific configuration
    alias ll='ls -lh --color=auto'
fi
```

### List All Tracked Files

```bash
# Show all files being tracked
dotfiles ls-tree -r HEAD --name-only
```

### Restore a Deleted File

```bash
# Restore a file you accidentally deleted
dotfiles checkout HEAD -- ~/.bashrc
```
