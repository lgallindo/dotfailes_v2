# dotfailes_v2 Roadmap & Implementation Plans

## Table of Contents
1. [Current Status](#current-status)
2. [Near-Term Plans (Priority 1)](#near-term-plans-priority-1)
3. [Medium-Term Plans (Priority 2)](#medium-term-plans-priority-2)
4. [Long-Term Plans (Priority 3)](#long-term-plans-priority-3)
5. [Multi-Setup Environment Strategy](#multi-setup-environment-strategy)
6. [GNU Stow Integration Plan](#gnu-stow-integration-plan)
7. [Completed Features](#completed-features)

---

## Current Status

### Version
- **Current**: v0.1.0 (Foundation phase)
- **Target**: v1.0.0 (Feature complete)
- **Stability**: Alpha (testing phase)

### Infrastructure
- ✅ Pipe-delimited logging format with metadata (TIMESTAMP|SCRIPT|USER|PWD|CALL|VERSION|KEY|VALUE)
- ✅ Row count headers [n] on all log files
- ✅ Rollback logging with executable revert commands
- ✅ Shell detection (bash, zsh, ksh, fish, dash)
- ✅ Interactive and non-interactive setup modes
- ✅ bats-core testing framework installed and working
- ✅ Multi-platform support (Linux, macOS, Windows)
- ✅ Downloaded dotfiles from Bitbucket repository

---

## Near-Term Plans (Priority 1)

### 1. Handle dotfailes init Return & Rollback
**Goal:** Gracefully handle failures during `dotfailes.sh init` and provide rollback capability.

**Implementation:**
```bash
# Capture return status and output
init_output=$(./$SCRIPT init "$REPO_PATH" "$SETUP_NAME" "$DOTFILES_FOLDER" 2>&1)
init_status=$?

if [[ $init_status -ne 0 ]]; then
    append_rollback "init_failed" "Repository initialization failed: $init_output" "rm -rf '$REPO_PATH'"
    error "Initialization failed. Use --rollback to revert."
    exit 1
fi
```

**Rollback additions:**
- Add `--rollback-init` flag to detect and revert bare repo initialization
- Clean up repo directory on rollback
- Preserve error logs for debugging

**Files affected:**
- `install.sh` - enhanced error handling
- `dotfailes.sh` - error reporting
- `rollback.log` - initialization failures tracked

---

### 2. Change Row Count Format to [n|HEADER]
**Goal:** Make log headers self-documenting with delimiter specification.

**Current:** `[5]` (just count)  
**Proposed:** `[5|TIMESTAMP|SCRIPT|USER|PWD|CALL|VERSION|KEY|VALUE]` (count + header)

**Benefits:**
- Declares field count AND delimiter in header
- Compatible with TOON format (Tab/CSV Organized Object Notation)
- Self-documenting for parsers
- Easier validation: count fields to verify integrity

**Implementation in `update_log_headers()`:**
```bash
update_log_headers() {
    if [[ -f "./logs/config.log" ]]; then
        header=$(head -n2 ./logs/config.log | tail -n1)  # First data row
        field_count=$(echo "$header" | awk -F'|' '{print NF}')
        sed -i '1s/^/['"$CONFIG_ROW_COUNT"'|'"$header"']\n/' ./logs/config.log
    fi
    # Same for rollback.log with 9 fields
}
```

**Files affected:**
- `install.sh` - update_log_headers() function
- `PARSEABILITY.md` - update examples
- `test/install.bats` - update header validation tests

---

## Medium-Term Plans (Priority 2)

### 3. Remove dotfailes.sh JSON Dependency
**Goal:** Replace `~/.dotfailes/config.json` with pipe-delimited CSV format.

**Motivation:**
- Single unified logging/config format across all tools
- Eliminates jq dependency (no external tools needed)
- Consistent with existing config.log/rollback.log formats
- Easier to parse in pure bash

**New config location:** `~/.dotfailes/config.csv`

**Format:**
```
[n|TIMESTAMP|SCRIPT|USER|PWD|CALL|VERSION|SETUP_NAME|SETUP_OS|SETUP_FOLDER|SETUP_REPO]
2025-12-22T14:00:00.000Z|dotfailes.sh|lucas|/home/lucas|dotfailes.sh init|1|my-setup|macOS|/home/lucas|/home/lucas/.dotfiles
```

**Migration strategy:**
1. Create migration function in dotfailes.sh
2. On first run: convert old JSON to new CSV format
3. Update cmd_init, cmd_clone to write CSV instead of JSON
4. Update cmd_list, cmd_status to read from CSV
5. Add CSV query function (grep-based, no jq needed)
6. Remove jq dependency check from install.sh (optional, keep for backward compat)

**CSV Query Examples:**
```bash
# List all setups for macOS
grep '|macOS|' ~/.dotfailes/config.csv

# Get repo path for specific setup
grep "^.*|setup-name|" ~/.dotfailes/config.csv | cut -d'|' -f9

# Count setups
grep -c '^[0-9]' ~/.dotfailes/config.csv
```

**Files affected:**
- `dotfailes.sh` - all cmd_* functions
- `install.sh` - remove jq dependency (or make optional)
- `PARSEABILITY.md` - add CSV query examples

---

### 4. Multi-Setup Environment Management (CSV-Based Hierarchical)
**Goal:** Support managing dotfiles across diverse environments with inheritance to reduce duplication.

See [Multi-Setup Environment Strategy](#multi-setup-environment-strategy) section for full details.

**Quick summary:**
- Proposal D (CSV-Based Hierarchical Setup) recommended
- Uses parent-child relationships in config.csv
- Semantic naming: `env-location-os-shell[-variant]`
- Examples: `work-macos-zsh`, `home-ubuntu22-bash`, `windows11-pwsh-7.3`
- Manifest files define which files apply per setup
- Inheritance reduces duplication

---

## Long-Term Plans (Priority 3)

### 5. Enhanced Features
- Support multiple dotfiles setups per machine (using CSV rows)
- Automated sync across machines (pull/push from CSV)
- Conflict resolution strategies for dotfiles
- Encrypted secrets management
- CI/CD integration for dotfiles
- Cross-machine state synchronization
- Backup and restore capabilities

### 6. Performance & Scale
- Optimize CSV parsing for large setups
- Parallel processing for multi-setup deployments
- Lazy loading for infrequently used setups
- Caching mechanisms for faster queries

### 7. User Experience
- Interactive setup wizard improvements
- Configuration validation before deployment
- Dry-run mode to preview changes
- Detailed change logs and diffs
- Web dashboard for log review (future)

---

## Multi-Setup Environment Strategy

### Problem
A typical developer uses multiple machines with:
- **OS variation**: macOS (M1/M2), Windows (10/11 with WSL), Ubuntu (20.04/22.04)
- **Shell variation**: zsh on macOS, bash on Linux, PowerShell on Windows, Git Bash
- **Environment variation**: work laptop, personal desktop, cloud VMs, containers
- **Version variation**: dotfile versions may need to differ by OS/shell/version

Current approach treats all setups equally. This doesn't scale when:
- `.zshrc` on macOS differs significantly from `.zshrc` on Linux
- Windows PowerShell profiles differ from Git Bash profiles
- Work configurations must be isolated from personal ones

### Recommended Solution: CSV-Based Hierarchical Setup (Proposal D)

#### Config Structure
**File:** `~/.dotfailes/config.csv`
```
[3|TIMESTAMP|SCRIPT|USER|PWD|CALL|VERSION|SETUP_NAME|PARENT_SETUP|OS|OS_VERSION|SHELL|SHELL_VERSION|ENV_TYPE|MANIFEST_PATH]
2025-12-22T14:00:00.000Z|dotfailes.sh|lucas|/home/lucas|dotfailes.sh init|1|base-macos|NULL|macOS|13.2|zsh|5.9|personal|manifests/base-macos.csv
2025-12-22T14:05:00.000Z|dotfailes.sh|lucas|/home/lucas|dotfailes.sh init|1|work-macos|base-macos|macOS|13.2|zsh|5.9|work|manifests/work-macos.csv
```

#### Manifest CSV Format
**File:** `manifests/base-macos.csv`
```
[4|TIMESTAMP|SCRIPT|SOURCE|TARGET|MERGE_STRATEGY]
2025-12-22T14:00:00.000Z|dotfailes.sh|files/common/.gitconfig|~/.gitconfig|replace
2025-12-22T14:00:01.000Z|dotfailes.sh|files/macos/.zshrc|~/.zshrc|merge
2025-12-22T14:00:02.000Z|dotfailes.sh|files/shell/zsh/|~/.zsh.d/|copy_dir
```

#### Inheritance Model
```
base-macos (parent: NULL)
  ├── Apply: files/common/.gitconfig → ~/.gitconfig
  ├── Apply: files/macos/.zshrc → ~/.zshrc
  └── Apply: files/shell/zsh/ → ~/.zsh.d/

work-macos (parent: base-macos)
  ├── Inherit: All of base-macos
  ├── Override: files/work/.gitconfig → ~/.gitconfig (merge strategy)
  └── Add: files/work/.ssh/config → ~/.ssh/config
```

#### Naming Convention
**Format:** `[env-]location-os-shell[-variant]`

**Examples:**
- `base-macos` - Base setup for macOS
- `base-ubuntu-bash` - Base setup for Ubuntu with bash
- `cloud-ubuntu-bash` - Cloud VM setup
- `work-macos-zsh` - Work laptop setup
- `work-windows-pwsh-7.3` - Work Windows with PowerShell 7.3+
- `home-macos-zsh-m1` - Home Mac with M1 architecture
- `docker-debian-bash-dev` - Docker container setup

#### Pros
- ✅ CSV-native: consistent with existing dotfailes logging
- ✅ No new tools: pure bash + CSV parsing (no jq, YAML, JSON)
- ✅ Hierarchical: inheritance reduces duplication
- ✅ Flexible naming: clear semantic naming conventions
- ✅ Auditable: full history in single config.csv
- ✅ Mergeable: git diff/merge works naturally on CSVs
- ✅ Testable: manifests can be validated independently
- ✅ Portable: CSV format works across all platforms/shells

#### Implementation Steps
1. Design manifest.csv format in detail (file paths, merge strategies)
2. Implement `dotfailes init --parent <parent_setup>` for inheritance
3. Implement manifest validation (circular dependency detection)
4. Update install.sh to support setup inheritance
5. Create example manifests for common environments
6. Add tests for inheritance chains and merge strategies

#### Example Environments

**Example 1: Personal MacBook Pro (M1)**
```
Setup: home-macos-m1-zsh
  OS: macOS 13 (Ventura)
  Shell: zsh 5.9
  Hardware: Apple Silicon M1
  Parent: base-macos
  Includes:
    - .zshrc (with M1-specific paths)
    - .gitconfig (personal github)
    - Homebrew paths
    - Vim configuration
```

**Example 2: Work Linux VM**
```
Setup: work-ubuntu22-bash
  OS: Ubuntu 22.04 LTS
  Shell: bash 5.1
  Hardware: x86_64 VM
  Parent: base-ubuntu-bash
  Includes:
    - .bashrc (with company paths)
    - .gitconfig (company git server)
    - SSH config (company keys)
    - Private certificate store
```

**Example 3: Windows Dual-Shell**
```
Setup: windows11-pwsh-work
  OS: Windows 11
  Shell 1: PowerShell 7.3
  Shell 2: Git Bash
  Parent: base-windows
  Includes:
    - Microsoft.PowerShell_profile.ps1 (work profile)
    - .bashrc (Git Bash, work mode)
    - WSL config (if installed)
    - Windows Terminal settings
```

---

## GNU Stow Integration Plan

### Objective
Allow users to optionally use GNU Stow for symlink management instead of direct file copying.

**Note:** Direct symlinks will NOT be used in default dotfailes_v2 installation. This is for users who want to integrate with GNU Stow separately.

### Why GNU Stow?
- Professional symlink management
- Handles complex scenarios with multiple package trees
- Automatic conflict detection
- Easy unstow/rollback
- Widely adopted in Linux/Unix communities
- Mature, well-tested tool

### Proposed Integration

#### 1. Stow Directory Structure
Users organizing their dotfiles with Stow would structure as:
```
~/.dotfiles/
├── .stow-local-ignore        # Stow ignore rules
├── stow-packages/
│   ├── bash/
│   │   └── .bashrc
│   ├── zsh/
│   │   ├── .zshrc
│   │   └── .zshenv
│   ├── common/
│   │   ├── .gitconfig
│   │   └── .gitignore
│   └── macos/
│       └── .zshenv
└── dotfiles_manifest.csv     # dotfailes manifest
```

#### 2. Stow Integration Mode
New flag: `dotfailes init --use-stow`

When enabled:
```bash
# Instead of copying files
cp files/bash/.bashrc ~/.bashrc

# Stow would do:
cd ~/.dotfiles
stow -t ~ bash

# Unstow (rollback):
stow -D -t ~ bash
```

#### 3. Hybrid Approach
Support BOTH methods in same setup:
```
[4|TIMESTAMP|SCRIPT|SOURCE|TARGET|MERGE_STRATEGY]
2025-12-22T14:00:00.000Z|dotfailes.sh|files/common/.gitconfig|~/.gitconfig|copy
2025-12-22T14:00:01.000Z|dotfailes.sh|stow-packages/bash|~|stow
2025-12-22T14:00:02.000Z|dotfailes.sh|files/macos/.zshenv|~/.zshenv|copy
```

#### 4. Prerequisites Checking
New validation in install.sh:
```bash
check_stow() {
    if ! command -v stow &> /dev/null; then
        error "GNU Stow is not installed"
        echo "Install Stow:"
        echo "  macOS:     brew install stow"
        echo "  Ubuntu:    sudo apt-get install stow"
        echo "  Fedora:    sudo dnf install stow"
        exit 1
    fi
}
```

#### 5. Manifest Extensions
Manifest supports both copy and stow strategies:
```
MERGE_STRATEGY options:
  - copy      (default, direct file copy)
  - copy_dir  (recursive directory copy)
  - merge     (merge file content)
  - stow      (use GNU Stow for symlinks)
  - stow-no-folding (stow without creating directories)
```

#### 6. Rollback with Stow
Rollback commands for stow operations:
```
ACTION: stow_applied
DESCRIPTION: Applied stow package 'bash' to home directory
REVERT_SHELL_COMMAND: cd ~/.dotfiles && stow -D -t ~ bash
```

#### 7. Documentation
Create `STOW_INTEGRATION.md` with:
- When to use Stow vs direct copy
- Stow configuration best practices
- Conflict resolution
- Performance considerations
- Migration from copy to Stow
- Examples for complex setups

#### 8. Implementation Plan
1. Phase 1: Document Stow integration requirements
2. Phase 2: Add `--use-stow` flag to install.sh
3. Phase 3: Implement Stow strategy in manifest parser
4. Phase 4: Add prerequisite checking for stow
5. Phase 5: Create stow-compatible example setups
6. Phase 6: Add tests for Stow operations
7. Phase 7: Document best practices and gotchas

### Stow Usage Examples

**Example 1: Simple bash setup with Stow**
```bash
cd ~/.dotfiles
mkdir -p stow-packages/bash
cp ~/.bashrc stow-packages/bash/
stow -t ~ bash
```

**Example 2: Multiple packages with dotfailes**
```bash
dotfailes init ~/.dotfiles my-setup ~ --use-stow
# Manifest will stow bash, zsh, common packages
```

**Example 3: Selective stowing**
```bash
# Stow only bash, copy other files directly
dotfailes init ~/.dotfiles my-setup ~ --use-stow --stow-packages bash,zsh
```

### Benefits of Integration
- Users familiar with Stow can leverage existing workflows
- Symlink conflicts detected automatically by Stow
- Easy to manage multiple package sets
- Professional-grade dotfile management
- Non-breaking: users without Stow still use default copy method

### Limitations to Document
- Stow doesn't work on Windows (use WSL or alternatives)
- Symlinks require proper filesystem support
- Circular symlinks can cause issues
- Not suitable for all file types (binaries, etc.)

---

## Completed Features

### Version 0.1.0 Achievements
- ✅ Pipe-delimited logging format with metadata
- ✅ Row count headers [n] on log files
- ✅ Rollback logging with executable revert commands
- ✅ Shell detection (bash, zsh, ksh, ksh93, dash, fish)
- ✅ Interactive and non-interactive modes
- ✅ bats-core testing framework (3/3 tests passing)
- ✅ Multi-platform support (macOS, Linux, Windows)
- ✅ README.md with installation instructions
- ✅ PARSEABILITY.md with usage examples
- ✅ Downloaded dotfiles from Bitbucket repository

### Known Issues / Backlog
- Non-interactive mode may exit early in some scenarios (captured in logs)
- OS-specific shell recommendations need refinement
- Windows PowerShell support needs additional testing
- CRLF line ending handling automated

---

## Testing Strategy

### Unit Tests
- Manifest parsing and validation
- CSV reading/writing
- Setup inheritance chains
- Rollback command generation

### Integration Tests
- Multi-setup deployments
- Stow operations
- JSON to CSV migration
- Cross-platform setup execution

### End-to-End Tests
- Complete installation from repo
- Multiple environment setups
- Rollback operations
- Inheritance chain resolution

### Testing Frameworks
- bats-core for bash scripts
- CSV validation scripts
- Manifest validator

---

## Release Timeline

### v0.2.0 (Q1 2026)
- Handle dotfailes init return codes and rollback
- Change row count format to [n|HEADER]
- Improve error handling and logging

### v0.5.0 (Q2 2026)
- Remove JSON dependency from dotfailes.sh
- Implement multi-setup environment management
- Add setup inheritance support
- Create example manifests

### v1.0.0 (Q3 2026)
- GNU Stow integration
- Comprehensive documentation
- Stable API
- Full test coverage

---

## References

### Related Documents
- `PARSEABILITY.md` - CSV parsing examples for bash/zsh/PowerShell
- `MULTI_SETUP_PROPOSAL.md` - Detailed comparison of multi-setup approaches
- `README.md` - Installation and usage guide
- `test/install.bats` - Automated tests

### External Tools
- [bats-core](https://github.com/bats-core/bats-core) - Bash Automated Testing System
- [GNU Stow](https://www.gnu.org/software/stow/) - Symlink farm management
- Bitbucket - Remote repository hosting

---

## Contributing

All contributions should:
1. Include updated tests in `test/install.bats`
2. Update relevant documentation files
3. Follow existing code style and conventions
4. Add entries to logs (config.log/rollback.log)
5. Include commit message with co-author: `Co-Authored-By: Warp <agent@warp.dev>`

---

## License

GNU General Public License v3.0 - See LICENSE file

---

**Last Updated:** 2025-12-22  
**Maintained by:** dotfailes_v2 Development Team  
**Current Version:** 0.1.0 (Alpha)
