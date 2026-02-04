# install.sh Workflow Documentation

## Overview

`install.sh` is the bootstrap script for setting up a dotfiles management system using a bare Git repository approach. It configures environment-specific dotfiles tracking, creates shell aliases, and logs all configuration changes with rollback capability.

---

## What BATS Tests Cover

### Unit Tests (Individual Functions)

1. **`detect_os()`** - Operating system detection
   - Tests Linux detection (from `Linux*` uname)
   - Tests MacOS detection (from `Darwin*` uname)
   - Tests Windows detection (from `MINGW*`/`CYGWIN*`/`MSYS*` uname)

2. **Output Functions** - Colored console output
   - `info()` - Blue `[INFO]` prefix messages
   - `success()` - Green `[SUCCESS]` prefix messages
   - `warn()` - Yellow `[WARN]` prefix messages
   - `error()` - Red `[ERROR]` prefix messages to stderr

3. **`append_config()`** - Configuration logging
   - Creates `./logs/` directory
   - Creates `config.log` with header on first write
   - Logs pipe-delimited entries (8 fields): `TIMESTAMP|SCRIPT|USER|PWD|CALL_ARGS|VERSION|KEY|VALUE`
   - Validates proper field structure

### Integration Tests (Full Script)

1. **Log File Creation** - Verifies `config.log` is created with proper structure
2. **Format Validation** - Ensures pipe-delimited format with correct field counts
3. **Timestamp Format** - Validates ISO-8601 timestamps
4. **Metadata Capture** - Confirms script name, version, and user info are logged
5. **Row Count Summary** - Checks `# TOTAL_ROWS:` footer is appended
6. **Help Output** - Tests `--help` flag shows usage information
7. **Non-Interactive Mode** - Full execution with CLI arguments

### Skipped Tests (Manual Only)

- `check_jq()` - Requires uninstalling jq
- `check_git()` - Requires uninstalling git

---

## install.sh Expected Workflow

### 1. Initialization Phase

```
START
  ↓
Set strict error handling (set -e)
  ↓
Initialize colors and variables
  ↓
Detect OS and hostname
  ↓
Display environment info (detected_os, hostname, TERM_PROGRAM)
  ↓
Set up EXIT trap → update_log_headers()
```

### 2. Execution Entry Point

```
main "$@"  ← Script arguments passed here
  ↓
Log CALL_ARGS to config.log
  ↓
Parse CLI arguments (while loop)
```

**CLI Arguments:**
- `--repo-path PATH` → Where bare Git repo will be stored
- `--setup-name NAME` → Identifier for this machine/setup
- `--dotfiles-folder DIR` → Working tree directory (actual files)
- `--no-alias` → Skip shell alias creation
- `--remote URL` → Git remote URL for dotfiles repo
- `--shell SHELL` → Force specific shell (bash/zsh/ksh/dash/fish)
- `--rollback` → Undo previous installation
- `--help` → Show usage and exit

### 3. Prerequisites Check

```
check_jq()
  ↓
  Is jq installed? ──NO──> Show install instructions → EXIT(1)
  ↓ YES
  ↓
check_git()
  ↓
  Is git installed? ──NO──> Error message → EXIT(1)
  ↓ YES
```

### 4. Rollback Mode (if `--rollback`)

```
rollback()
  ↓
Read last CSV config entry
  ↓
Remove alias from shell config (with backup)
  ↓
Prompt: Remove repo directory? (y/n)
  ↓ YES
Remove $REPO_PATH
  ↓
Prompt: Remove CSV config? (y/n)
  ↓ YES
Remove install_config.csv
  ↓
EXIT
```

### 5. Shell Detection

```
detect_shell()
  ↓
Read $SHELL_CHOICE (from --shell or "auto")
  ↓
Determine:
  - DETECTED_SHELL (bash/zsh/ksh/fish/etc)
  - SCRIPT (dotfailes.sh/dotfailes.zsh/etc)
  - SHELL_CONFIG (~/.bashrc, ~/.zshrc, etc)
  ↓
Log: OS, SHELL, SCRIPT, SHELL_CONFIG
```

### 6. Mode Selection

#### 6A. Non-Interactive Mode
*(If `--repo-path`, `--setup-name`, and `--dotfiles-folder` all provided)*

```
Display config info
  ↓
Execute: ./$SCRIPT init "$REPO_PATH" "$SETUP_NAME" "$DOTFILES_FOLDER"
  ↓
Create alias? (unless --no-alias)
  ↓ YES
Determine alias target:
  - ~/.bash_aliases (if sourced from ~/.bashrc)
  - OR $SHELL_CONFIG
  ↓
Append alias:
  # dotfailes alias (repo: <URL>)
  alias dotfiles='git --git-dir=$REPO_PATH --work-tree=$DOTFILES_FOLDER'
  ↓
Log rollback instruction
  ↓
Log: REPO_PATH, SETUP_NAME, DOTFILES_FOLDER, REPO_URL
  ↓
Add git remote? (if --remote provided)
  ↓ YES
git remote add origin "$REPO_URL"
git push --set-upstream origin main
  ↓
SUCCESS: Setup complete!
```

#### 6B. Interactive Mode
*(If any of the required params are missing)*

```
Prompt: Initialize dotfiles repository now? (y/n)
  ↓ NO → Show manual instructions → EXIT
  ↓ YES
  ↓
Prompt: Repository path?
  Default: $HOME/.dotfiles
  Read: $REPO_PATH
  ↓
Prompt: Setup name?
  Default: $(hostname)-$(OS)
  Read: $SETUP_NAME
  ↓
Prompt: Dotfiles folder?
  Default: $HOME
  Read: $DOTFILES_FOLDER
  ↓
Execute: ./$SCRIPT init "$REPO_PATH" "$SETUP_NAME" "$DOTFILES_FOLDER"
  ↓
Log: CONFIG_FILE location
  ↓
Prompt: Add dotfiles alias to $SHELL_CONFIG? (y/n)
  ↓ YES
    ↓
    Prompt: Enter repo URL (optional)
    Read: $REPO_URL
    ↓
    Determine alias target (same logic as non-interactive)
    ↓
    Append alias with comment
    ↓
    Log rollback instruction
  ↓
Log: REPO_PATH, SETUP_NAME, DOTFILES_FOLDER, REPO_URL
  ↓
Add git remote? (if URL provided)
  ↓ YES
git remote add origin "$REPO_URL"
git push --set-upstream origin main
  ↓
Display next steps:
  1. Source shell config
  2. Hide untracked files
  3. Add first dotfile
  4. Commit
  5. Add remote (if not done)
```

### 7. Finalization

```
chmod +x "$SCRIPT"
  ↓
Display: "See README.md and EXAMPLES.md"
  ↓
EXIT trap fires → update_log_headers()
  ↓
Append row counts to logs:
  - config.log: # TOTAL_ROWS: N
  - rollback.log: # TOTAL_ROWS: N
  ↓
END
```

---

## Key Files Created

### Logs Directory (`./logs/`)

**config.log** format:
```
# TIMESTAMP|SCRIPT|USER|PWD|CALL_ARGS|VERSION|KEY|VALUE
2026-02-03T14:30:00.123Z|install.sh|user|/path|--repo-path ...|1.0.0|CALL|--repo-path ...
2026-02-03T14:30:00.456Z|install.sh|user|/path|--repo-path ...|1.0.0|OS|Linux
2026-02-03T14:30:00.789Z|install.sh|user|/path|--repo-path ...|1.0.0|SHELL|bash
...
# TOTAL_ROWS: 8
```

**rollback.log** format:
```
# TIMESTAMP|SCRIPT|USER|PWD|CALL_ARGS|VERSION|ACTION|DESCRIPTION|REVERT_CMD
2026-02-03T14:30:05.123Z|install.sh|user|/path|...|1.0.0|alias_added|Added alias|grep -v 'dotfiles' ...
# TOTAL_ROWS: 1
```

### Shell Configuration

Modified file (e.g., `~/.bashrc` or `~/.bash_aliases`):
```bash
# dotfailes alias (repo: https://github.com/user/dotfiles)
alias dotfiles='git --git-dir=/home/user/.dotfiles --work-tree=/home/user'
```

### Dotfailes Config

Created by called script (`dotfailes.sh`):
```json
$HOME/.dotfailes/config.json
```

---

## Error Handling

- **`set -e`**: Script exits immediately on any command failure
- **Exit trap**: `update_log_headers()` always executes, even on error
- **Prerequisite checks**: jq and git must be installed
- **Directory validation**: Prompts before deleting in rollback mode
- **Backup creation**: Shell config backed up before rollback removal

---

## Environment Variables Used

- `$SHELL` - Detects current shell
- `$HOME` - Default paths
- `$USER` - Logged in metadata
- `$PWD` - Logged in metadata
- `$TERM_PROGRAM` - Displayed for debugging
- `$SHELL_CHOICE` - Override shell detection
- `$GIT_EXECUTABLE` - Override git command (if set)

---

## Design Principles

1. **Idempotent**: Can be run multiple times safely
2. **Logged**: All configuration changes tracked with timestamps
3. **Reversible**: Rollback instructions stored
4. **Cross-platform**: Supports Linux, MacOS, Windows (Git Bash/MSYS2)
5. **Shell-agnostic**: Detects and configures bash/zsh/ksh/fish/dash
6. **Machine-parseable**: Pipe-delimited logs for automation
7. **Interactive & scriptable**: Works in both modes

---

## Dependencies

**Required:**
- bash 3.2+
- git
- jq
- Standard Unix utilities (date, grep, sed, awk, hostname, uname)

**Optional:**
- dos2unix (for line ending conversion on Windows)

---

## Common Use Cases

### 1. Fresh Installation (Interactive)
```bash
./install.sh
# Follow prompts
```

### 2. Automated Setup (CI/CD)
```bash
./install.sh \
  --repo-path "$HOME/.dotfiles" \
  --setup-name "$(hostname)-production" \
  --dotfiles-folder "$HOME" \
  --remote "git@github.com:user/dotfiles.git" \
  --shell bash \
  --no-alias
```

### 3. Undo Installation
```bash
./install.sh --rollback
```

### 4. Different Shell
```bash
./install.sh --shell zsh
```

---

## Next Steps After Installation

As displayed by the script:

1. **Source shell config**: `source ~/.bashrc`
2. **Hide untracked files**: `dotfiles config --local status.showUntrackedFiles no`
3. **Add first dotfile**: `dotfiles add ~/.bashrc`
4. **Commit**: `dotfiles commit -m 'Initial commit'`
5. **Add remote** (if not done): `dotfiles remote add origin <url>`
