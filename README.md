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

---

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

| Command | Usage | Description |
| :--- | :--- | :--- |
| `setup:show` | `dots setup:show` | Detailed info for the current/selected setup. |
| `registry:list` | `dots registry:list` | List known remote repository templates. |
| `registry:use` | `dots registry:use <name>` | Point the current setup to a registry remote. |

### Daily Workflow (Git Proxy)

Commands like `add`, `commit`, `push`, `pull`, `diff`, `log`, and `status` are proxied directly to the bare git repository of the active setup.

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

## Logging & Auditability

All operations are recorded in the `~/.dotfailes/logs/` directory using the **TOON** (Tab/CSV Organized Object Notation) format.

### Log Format `[n|HEADER]`
Files start with a metadata header containing the row count and field names:
`[5|TIMESTAMP|SCRIPT|USER|PWD|CALL|VERSION|KEY|VALUE]`

Refer to [PARSEABILITY.md](PARSEABILITY.md) for examples on how to query logs and configs using `grep`, `awk`, or PowerShell.

---

## Advanced: Bare Git Repository Manual Usage

If you prefer using git directly, the `install.sh` script creates an alias like this:

```bash
alias dots='git --git-dir=$HOME/.dotfiles --work-tree=$HOME'
```

This allows you to manage your dotfiles exactly like any other git repository without moving them into a specific folder.

---

## Troubleshooting

- **"Setup not found"**: Ensure you have run `dots init` or `dots clone`. Check `~/.dotfailes/config.csv`.
- **Conflicts on Checkout**: If files already exist, move them to a backup folder before checking out:
  `dots checkout 2>&1 | grep -E "^\s+" | awk {'print $1'} | xargs -I{} mv {} ~/.dotfiles-backup/{}`

## License

This project is licensed under the GNU General Public License v3.0.

---

## Acknowledgments

Inspired by the "bare git repository" technique for dotfile management. Standardized for high-compliance and multi-setup environments.
