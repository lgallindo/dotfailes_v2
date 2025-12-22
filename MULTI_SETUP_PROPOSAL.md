# Multi-Setup Environment Management Proposal
## Executive Summary
This document proposes strategies for managing dotfiles across diverse computing environments: different operating systems, shells, versions, and hardware configurations. The goal is to maintain a single dotfiles repository while supporting customizations for:
- OS variants (Windows 10/11, Ubuntu/Debian, macOS versions)
- Shell variants (bash, zsh, fish, Git Bash, MSYS2, PowerShell)
- Architecture/hardware (x86_64, ARM, WSL)
- Application versions and configurations

## Problem Statement
A typical developer uses multiple machines with:
- **OS variation**: MacOS (M1/M2), Windows (10/11 with WSL), Ubuntu (20.04/22.04)
- **Shell variation**: zsh on macOS, bash on Linux, PowerShell on Windows, Git Bash on Windows
- **Environment variation**: work laptop, personal desktop, cloud VMs, containers
- **Version variation**: dotfile versions may need to differ by OS/shell/version

Currently, dotfailes treats all setups equally with a single `~/.dotfailes/config.csv`. This doesn't scale well when:
- `.zshrc` on macOS differs significantly from `.zshrc` on Linux
- Windows PowerShell profiles differ from Git Bash profiles
- Work configurations must be isolated from personal ones

## Proposal A: Branch-Based Organization
### Structure
```
Repository branches:
main/                          # Base/common dotfiles
├── .bashrc (common shell setup)
├── .bash_aliases
└── .gitconfig (common)

feature/macos-zsh/             # macOS with zsh
├── .zshrc
├── .zshenv
└── overrides/ (replaces common files)

feature/ubuntu-bash/           # Ubuntu with bash
├── .bashrc (overrides main)
├── .bashrc.d/
└── ubuntu-specific.conf

feature/windows-pwsh/          # Windows with PowerShell
├── Microsoft.PowerShell_profile.ps1
└── windows-specific/

feature/work-laptop/           # Work-specific overrides
├── .gitconfig (company git)
├── ssh/config
└── .env.work
```

### Naming Convention
**Format:** `feature/OS-shell[-variant][-version]`

Examples:
- `feature/macos-zsh` - macOS with zsh (any version)
- `feature/macos-zsh-14` - macOS with zsh 14+ specifically
- `feature/ubuntu22-bash` - Ubuntu 22.04 with bash
- `feature/windows11-pwsh-7.3` - Windows 11 with PowerShell 7.3+
- `feature/work-macos-zsh` - Work laptop, macOS, zsh (inherits from macos-zsh)
- `feature/wsl2-ubuntu-bash` - WSL2 Ubuntu with bash

### Implementation
1. **Base setup** runs main branch (common files)
2. **Feature branches** contain OS/shell-specific overrides
3. **Git merge strategy**: checkout main, then cherry-pick/merge specific branch files
4. **Config CSV tracks**: setup_name → branch mapping

```
TIMESTAMP|SCRIPT|USER|PWD|CALL|VERSION|SETUP_NAME|BRANCH|OS|SHELL|REPO_PATH
```

### Pros
- ✅ Git-native: leverage existing branch infrastructure
- ✅ Clear inheritance: can merge parent branches (e.g., macos-zsh ← main)
- ✅ Version control: full history per environment
- ✅ Collaboration: team members see all environment configs
- ✅ Rollback: git revert to previous branch state
- ✅ Diff-friendly: easy to compare environments (`git diff feature/macos-zsh feature/ubuntu-bash`)

### Cons
- ❌ Many branches: repository becomes cluttered with N×M branches (OS × shell × variants)
- ❌ Merge complexity: managing cross-branch dependencies is error-prone
- ❌ Not semantic: branch names are not standardized across teams
- ❌ Hard to detect incompatibilities: mixing incompatible features can break configs
- ❌ Checkout workflow: users must explicitly check out correct branch
- ❌ CI/CD burden: testing all branch combinations is expensive

---

## Proposal B: Folder-Based Organization
### Structure
```
Repository structure:
.
├── common/                     # Files shared across all setups
│   ├── .gitconfig
│   ├── .bash_aliases
│   └── includes.sh            # Load platform-specific code
│
├── os/                         # OS-specific configurations
│   ├── macos/
│   │   ├── .zshrc
│   │   ├── .zshenv
│   │   └── .bashrc.d/
│   ├── linux/
│   │   ├── ubuntu/
│   │   │   └── sources.list
│   │   ├── debian/
│   │   │   └── apt.conf
│   │   └── .bashrc
│   └── windows/
│       ├── Microsoft.PowerShell_profile.ps1
│       ├── git-bash/
│       │   └── .bashrc
│       └── msys2/
│
├── shell/                      # Shell-specific configurations
│   ├── zsh/
│   │   ├── .zshrc (universal zsh setup)
│   │   ├── .zshenv
│   │   └── plugins/
│   ├── bash/
│   │   ├── .bashrc
│   │   └── .bash_profile
│   ├── pwsh/
│   │   └── profile.ps1
│   └── fish/
│
├── version/                    # Version-specific overrides
│   ├── macos-12/              # Monterey
│   ├── macos-13/              # Ventura
│   ├── ubuntu-22.04/
│   ├── windows-11/
│   └── zsh-5.9/
│
├── env/                        # Environment-specific (work, personal)
│   ├── work/
│   │   ├── .gitconfig
│   │   ├── ssh/config
│   │   └── .env.work
│   ├── personal/
│   │   └── .gitconfig
│   └── cloud/
│
└── setup-manifests/            # Define which files to use for each environment
    ├── macos-zsh.manifest
    ├── ubuntu-bash.manifest
    ├── windows-pwsh.manifest
    └── work-laptop-macos-zsh.manifest
```

### Manifest Format
**File:** `setup-manifests/macos-zsh.manifest`
```
# OS: macOS 13+
# Shell: zsh 5.9+
# Use case: Personal laptop

# Load order matters: later files override earlier ones
common/.gitconfig                    → ~/.gitconfig
common/.bash_aliases                 → ~/.bash_aliases
os/macos/.zshrc                      → ~/.zshrc
os/macos/.zshenv                     → ~/.zshenv
shell/zsh/.zshrc                     → ~/.zshrc (merge, not replace)
version/macos-13/.zshrc.override     → ~/.zshrc (optional overrides)
env/personal/.gitconfig              → ~/.gitconfig
```

### Implementation
1. **Installer logic**: Read manifest, copy/symlink files in order
2. **Merge conflicts**: Last-one-wins or script-based merging
3. **Config CSV tracks**: setup_name → manifest file mapping

```
TIMESTAMP|SCRIPT|USER|PWD|CALL|VERSION|SETUP_NAME|MANIFEST|OS|SHELL|REPO_PATH
```

### Pros
- ✅ Scalable: add new OS/shell without multiplying branches
- ✅ Clear semantics: folder names describe purpose
- ✅ Easy navigation: all Ubuntu configs in one folder
- ✅ Granular control: swap individual files per environment
- ✅ Manifest-driven: explicit declaration of which files apply
- ✅ Composable: combine multiple manifests (e.g., base + work + region)
- ✅ No git complexity: single main branch

### Cons
- ❌ Duplication: common code may be repeated across folders
- ❌ Manifest maintenance: must manually maintain mapping files
- ❌ Symlink issues: symlinks break on Windows, may cause confusion
- ❌ Large repository: folder structure grows quickly
- ❌ Version tracking: harder to see history of specific environment setup
- ❌ Testing burden: must verify all folder combinations

---

## Proposal C: Semantic Versioning + Metadata
### Structure
```
Repository structure:
.
├── configs/
│   ├── v1.0.0/                 # Semantic version (major.minor.patch)
│   │   ├── base.manifest       # Core for all environments
│   │   ├── macos-zsh.manifest
│   │   ├── ubuntu-bash.manifest
│   │   └── files/
│   │       ├── .gitconfig
│   │       ├── .bashrc
│   │       └── ... 
│   │
│   ├── v2.0.0/                 # New major version (breaking changes)
│   │   ├── base.manifest
│   │   └── files/
│   │
│   └── latest → v2.0.0         # Symlink to current version
│
├── environments/
│   ├── macos-13-zsh-5.9.yaml
│   ├── ubuntu-22.04-bash-5.1.yaml
│   ├── windows-11-pwsh-7.3.yaml
│   └── work-laptop.yaml         # Inherits from macos-13-zsh-5.9.yaml
│
└── .dotfailes/
    └── config.csv              # Maps setup_name → environment definition
```

### Environment Definition (YAML)
**File:** `environments/macos-13-zsh-5.9.yaml`
```yaml
# Multi-setup environment definition
metadata:
  id: "macos-13-zsh-5.9"
  version: "1.0"
  created: "2025-12-22T14:54:53Z"
  
system:
  os: "macOS"
  os_version: "13.x"           # Semantic: major.minor
  architecture: "arm64"
  
shell:
  name: "zsh"
  version: "5.9+"             # Minimum version
  
applications:
  git: "2.38+"
  vim: "9.0+"
  
setup:
  config_version: "1"
  manifests:
    - "v1.0.0/base.manifest"
    - "v1.0.0/macos-zsh.manifest"
  variables:
    EDITOR: "vim"
    SHELL: "/bin/zsh"
```

### OS Versioning Strategy
**Semantic versioning for dotfiles:**
- **Major (X.0.0)**: Breaking changes (e.g., new mandatory dependencies)
- **Minor (1.Y.0)**: New features (backward compatible)
- **Patch (1.0.Z)**: Bug fixes

**OS compatibility matrix:**
```
dotfailes v2.0.0 requires:
├── macOS 12+ (Monterey+)
├── Ubuntu 20.04+ (Focal+)
├── Windows 10 21H2+
├── bash 4.3+ OR zsh 5.0+
└── git 2.25+
```

### Implementation
1. **Installer**: Read environment YAML, validate compatibility, apply manifests
2. **Validation**: Check OS version, shell version, dependencies before setup
3. **Config CSV**: Tracks environment definition file per setup

```
TIMESTAMP|SCRIPT|USER|PWD|CALL|VERSION|SETUP_NAME|ENVIRONMENT|CONFIG_VERSION
```

### Pros
- ✅ Semantic clarity: version numbers convey compatibility
- ✅ Explicit compatibility: environment YAMLs declare requirements
- ✅ Dependency tracking: know which tools are required
- ✅ Rollback clarity: revert to v1.0.0 knows what to expect
- ✅ Scalable: add new environment without touching versioning scheme
- ✅ Testable: can validate environment definitions against actual systems
- ✅ Clear naming: macos-13-zsh-5.9 is unambiguous

### Cons
- ❌ YAML parsing: requires additional tooling or shell parsing library
- ❌ Complexity: three levels of organization (version/manifest/environment)
- ❌ Maintenance: YAML files must be kept in sync with actual configs
- ❌ Learning curve: users must understand versioning and environment structure
- ❌ Validation overhead: more steps before setup runs

---

## Proposal D: CSV-Based Hierarchical Setup (Recommended for dotfailes_v2)
### Structure
Single `~/.dotfailes/config.csv` with hierarchical setup definitions:

**File:** `~/.dotfailes/config.csv`
```
[5|TIMESTAMP|SCRIPT|USER|PWD|CALL|VERSION|SETUP_NAME|PARENT_SETUP|OS|OS_VERSION|SHELL|SHELL_VERSION|ENV_TYPE|MANIFEST_PATH]
2025-12-22T14:00:00.000Z|dotfailes.sh|lucas|/home/lucas|dotfailes.sh init|1|base-macos|NULL|macOS|13.2|zsh|5.9|personal|manifests/base-macos.csv
2025-12-22T14:05:00.000Z|dotfailes.sh|lucas|/home/lucas|dotfailes.sh init|1|work-macos|base-macos|macOS|13.2|zsh|5.9|work|manifests/work-macos.csv
2025-12-22T14:10:00.000Z|dotfailes.sh|lucas|/tmp|dotfailes.sh init|1|ubuntu-vm|NULL|Linux|22.04|bash|5.1|cloud|manifests/ubuntu-vm.csv
```

### Manifest CSV Format
**File:** `manifests/base-macos.csv`
```
[4|TIMESTAMP|SCRIPT|SOURCE|TARGET|MERGE_STRATEGY]
2025-12-22T14:00:00.000Z|dotfailes.sh|files/common/.gitconfig|~/.gitconfig|replace
2025-12-22T14:00:01.000Z|dotfailes.sh|files/macos/.zshrc|~/.zshrc|merge
2025-12-22T14:00:02.000Z|dotfailes.sh|files/shell/zsh/|~/.zsh.d/|copy_dir
2025-12-22T14:00:03.000Z|dotfailes.sh|files/macos/.zshenv|~/.zshenv|replace
```

**File:** `manifests/work-macos.csv`
```
[2|TIMESTAMP|SCRIPT|SOURCE|TARGET|MERGE_STRATEGY]
2025-12-22T14:05:00.000Z|dotfailes.sh|files/work/.gitconfig|~/.gitconfig|merge
2025-12-22T14:05:01.000Z|dotfailes.sh|files/work/.ssh/config|~/.ssh/config|merge
```

### Inheritance Model
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

### Naming Convention
**Format:** `[location]-[os]-[shell][-variant]` or `[env]-[location]-[os]-[shell]`

**Examples:**
```
base-macos
base-ubuntu-bash
base-windows-pwsh
cloud-ubuntu-bash
work-macos-zsh
work-windows-pwsh-7.3
home-macos-zsh-m1
vm-ubuntu22-bash-5.1
```

### Implementation
```bash
# Setup inheritance chain
setup_names=(base-macos work-macos)
for setup in "${setup_names[@]}"; do
    parent=$(grep "^.*|$setup|" ~/.dotfailes/config.csv | cut -d'|' -f7)
    if [[ -n "$parent" && "$parent" != "NULL" ]]; then
        apply_setup "$parent"  # Recursively apply parent
    fi
    apply_manifest "manifests/${setup}.csv"
done
```

### Pros
- ✅ CSV-native: consistent with existing dotfailes logging
- ✅ No new tools: pure bash + CSV parsing (no jq, YAML, JSON)
- ✅ Hierarchical: inheritance reduces duplication
- ✅ Flexible naming: clear semantic naming conventions
- ✅ Auditable: full history in single config.csv
- ✅ Mergeable: git diff/merge works naturally on CSVs
- ✅ Testable: manifests can be validated independently
- ✅ Portable: CSV format works across all platforms/shells

### Cons
- ❌ CSV verbosity: lots of repetition for complex setups
- ❌ Parsing: CSV parsing in bash is fragile (requires careful IFS handling)
- ❌ Circular dependencies: must prevent cycles in inheritance graph
- ❌ Learning: users must understand manifest format

---

## Comparison Matrix

| Aspect | Proposal A (Branches) | Proposal B (Folders) | Proposal C (Semantic) | Proposal D (CSV) |
|--------|:---:|:---:|:---:|:---:|
| **Scalability** | ❌ Poor | ✅ Good | ✅ Excellent | ✅ Good |
| **Git-native** | ✅ Yes | ❌ No | ❌ No | ✅ Yes |
| **Naming clarity** | ⚠️ Medium | ✅ High | ✅ High | ✅ High |
| **Maintenance burden** | ❌ High | ⚠️ Medium | ✅ Low | ✅ Low |
| **Inheritance support** | ⚠️ Via merges | ⚠️ Via includes | ✅ Explicit | ✅ Explicit |
| **Tool dependencies** | None | None | YAML parser | None |
| **Cross-platform** | ✅ Yes | ✅ Yes | ✅ Yes | ✅ Yes |
| **Version control** | ✅ Excellent | ⚠️ Good | ✅ Excellent | ✅ Good |
| **Consistency with dotfailes** | ⚠️ Some | ⚠️ Some | ❌ No | ✅ Excellent |

---

## Recommendation
**Proposal D (CSV-Based Hierarchical Setup)** is recommended for dotfailes_v2 because:

1. **Alignment**: Uses existing CSV format from config.log/rollback.log
2. **No dependencies**: Pure bash, no YAML/JSON/jq required
3. **Scalability**: N setups with M parents scales well (not N×M)
4. **Inheritance**: Parent-child relationships prevent duplication
5. **Auditability**: Full history in single config.csv file
6. **Git-friendly**: CSV diffs are readable and mergeable
7. **Portability**: Works on all platforms (Windows/macOS/Linux)
8. **Minimal learning curve**: Users already familiar with CSV format

### Next Steps
1. Design manifest.csv format in detail (file paths, merge strategies)
2. Implement `dotfailes init --parent <parent_setup>` for inheritance
3. Implement manifest validation (circular dependency detection)
4. Update install.sh to support setup inheritance
5. Create example manifests for common environments
6. Add tests for inheritance chains and merge strategies

---

## Appendix: Example Environments

### Example 1: Personal MacBook Pro (M1)
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

### Example 2: Work Linux VM
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

### Example 3: Windows Dual-Shell
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

Setup: windows11-git-bash
  Parent: windows11-pwsh-work
  Overrides:
    - .bashrc (personal customizations)
```

### Example 4: Containerized Development
```
Setup: docker-debian-bash-dev
  OS: Debian 11 (base image)
  Shell: bash 5.1
  Inherited: base-ubuntu-bash (compatible)
  Includes:
    - Development tool configurations
    - Container-specific paths
    - Mount point configurations
```
