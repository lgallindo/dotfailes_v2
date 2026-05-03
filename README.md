# dots_v2

**Version 1.0.0**

### Core Scripts

- [dots.sh](dots.sh): Primary bash script for managing dotfiles using bare git repositories.
- [install.sh](install.sh): Interactive/non-interactive installation and environment setup script.

### Documentation

- [Documentation Index](docs/README.md): Central hub for project policies and guides.

## Overview

**dots_v2** is a lightweight, cross-platform dotfile management system that uses bare git repositories to track and synchronize your configuration files across multiple machines. It supports Linux, MacOS, and Windows with dedicated scripts for each platform.

## Features

- **Bare Git Repositories**: Manage dotfiles without moving them from their original locations.
- **Cross-Platform**: Support for Bash, Zsh, and PowerShell.
- **Interactive Setup**: Simple installation script for quick configuration.
- **Non-Interactive Mode**: Fully automated installation via CLI flags.
- **Auditable History**: Rigid commit standards and log tracking.
- **Rollback System**: Easily revert configuration changes.

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
