#!/usr/bin/env bash
# dots - Dotfile management using bare git repositories
# Copyright (C) 2025
# Licensed under GNU General Public License v3.0

set -e

# Default configuration
DEFAULT_DOTFILES_DIR="${HOME}/.dotfailes"
DOTFILES_DIR="${DOTFILES_DIR:-$DEFAULT_DOTFILES_DIR}"
CONFIG_FILE="${DOTFILES_DIR}/config.csv"
REGISTRY_FILE="${DOTFILES_DIR}/registry.csv"
VERSION="1.1.0"

# Global state
SELECTED_SETUP=""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
_get_timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

info() {
    echo -e "${BLUE}[$(_get_timestamp)][INFO]${NC} $1" >&2
}

_get_timestamp_iso() {
    date -u +"%Y-%m-%dT%H:%M:%S.%3NZ"
}

# Helper to get a specific field from a setup in config.csv.
# Fields (1-based): 7:name, 8:os, 9:folder, 10:repo, 11:branch
_get_setup_field() {
    local setup_name="$1"
    local field_index="$2"
    grep -F "|$setup_name|" "$CONFIG_FILE" | head -n 1 | cut -d'|' -f"$field_index"
}

# Helper to update a specific field in a setup.
_update_setup_field() {
    local setup_name="$1"
    local field_index="$2"
    local new_value="$3"
    local tmp=$(mktemp)
    awk -v name="$setup_name" -v idx="$field_index" -v val="$new_value" -F'|' 'BEGIN{OFS="|"} { if ($7 == name) $idx = val; print }' "$CONFIG_FILE" > "$tmp" && mv "$tmp" "$CONFIG_FILE"
}

# Resolve setup name with defaults.
# Logic:
# 1. Use SELECTED_SETUP if provided via --setup global flag.
# 2. Fall back to the first setup defined in config.csv.
_resolve_setup_name() {
    if [[ -n "$SELECTED_SETUP" ]]; then
        echo "$SELECTED_SETUP"
    else
        init_config
        # First data row (skip header line starting with [)
        local default_setup=$(grep -v "^\[" "$CONFIG_FILE" | head -n 1 | cut -d'|' -f7)
        if [[ -z "$default_setup" ]]; then
            die "No setups configured yet. Use 'dots init' or 'dots clone' first."
        fi
        echo "$default_setup"
    fi
}

# Internal helper to execute git commands within a setup's context.
_git_run() {
    local setup_name="$1"
    shift
    local command="$1"
    shift

    init_config
    
    # Query CSV for setup (Field 7 is name)
    local setup_line=$(grep -F "|$setup_name|" "$CONFIG_FILE" | head -n 1)
    if [[ -z "$setup_line" ]]; then
        die "Setup '$setup_name' not found in configuration. Use 'dots list'."
    fi

    # Parse CSV fields (1-based: 7:name, 8:os, 9:folder, 10:repo, 11:branch)
    local repo_path=$(echo "$setup_line" | cut -d'|' -f10)
    local work_tree=$(echo "$setup_line" | cut -d'|' -f9)

    if [[ -z "$repo_path" ]]; then
        die "Setup '$setup_name' has no repository path configured."
    fi

    # Execute git
    git --git-dir="$repo_path" --work-tree="$work_tree" "$command" "$@"
}

success() {
    echo -e "${GREEN}[$(_get_timestamp)][SUCCESS]${NC} $1" >&2
}

warn() {
    echo -e "${YELLOW}[$(_get_timestamp)][WARN]${NC} $1" >&2
}

error() {
    echo -e "${RED}[$(_get_timestamp)][ERROR]${NC} $1" >&2
}

die() {
    error "$1"
    exit 1
}

# Initialize configuration file if it doesn't exist
# Initialize configuration file if it doesn't exist.
# Handles migration from JSON to CSV if old config is found.
init_config() {
    mkdir -p "$(dirname "$CONFIG_FILE")"

    # Migration from JSON to CSV
    local json_config="${CONFIG_FILE%.csv}.json"
    if [[ -f "$json_config" ]] && [[ ! -f "$CONFIG_FILE" ]]; then
        info "Migrating JSON configuration to CSV format..."
        local header="TIMESTAMP|SCRIPT|USER|PWD|CALL|VERSION|SETUP_NAME|SETUP_OS|SETUP_FOLDER|SETUP_REPO|SETUP_BRANCH"
        printf '[0|%s]\n' "$header" > "$CONFIG_FILE"
        
        # Migrating setups
        if command -v jq &>/dev/null; then
            jq -c '.setups[]' "$json_config" | while read -r setup; do
                local name=$(echo "$setup" | jq -r '.name')
                local os=$(echo "$setup" | jq -r '.os')
                local folder=$(echo "$setup" | jq -r '.folder')
                local repo=$(echo "$setup" | jq -r '.repo')
                local branch=$(echo "$setup" | jq -r '.branch // "main"')
                
                printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
                    "$(_get_timestamp_iso)" "dots.sh" "$USER" "$PWD" "migration" "$VERSION" \
                    "$name" "$os" "$folder" "$repo" "$branch" >> "$CONFIG_FILE"
            done
            # Update row count in header
            local count=$(grep -v "^\[" "$CONFIG_FILE" | wc -l)
            sed -i "1s/\[0|/[$count|/" "$CONFIG_FILE"
            
            # Migrating registry (if exists)
            printf '[0|TIMESTAMP|SCRIPT|USER|PWD|CALL|VERSION|REG_NAME|REG_URL|REG_DESC]\n' > "$REGISTRY_FILE"
            if jq -e '.remotes_registry' "$json_config" >/dev/null 2>&1; then
                jq -c '.remotes_registry[]' "$json_config" | while read -r reg; do
                    local name=$(echo "$reg" | jq -r '.name')
                    local url=$(echo "$reg" | jq -r '.url')
                    local desc=$(echo "$reg" | jq -r '.description // ""')
                    printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
                        "$(_get_timestamp_iso)" "dots.sh" "$USER" "$PWD" "migration" "$VERSION" \
                        "$name" "$url" "$desc" >> "$REGISTRY_FILE"
                done
            fi
            count=$(grep -v "^\[" "$REGISTRY_FILE" | wc -l)
            sed -i "1s/\[0|/[$count|/" "$REGISTRY_FILE"
            
            success "Migration complete. Old config archived as ${json_config}.bak"
            info "To rename your setups to a more semantic name, use: dots rename <old_name> <new_name>"
            mv "$json_config" "${json_config}.bak"
        else
            warn "jq not found. Could not migrate JSON config automatically."
        fi
    fi

    # Create empty CSVs if they don't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        local header="TIMESTAMP|SCRIPT|USER|PWD|CALL|VERSION|SETUP_NAME|SETUP_OS|SETUP_FOLDER|SETUP_REPO|SETUP_BRANCH"
        printf '[0|%s]\n' "$header" > "$CONFIG_FILE"
    fi
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        local header="TIMESTAMP|SCRIPT|USER|PWD|CALL|VERSION|REG_NAME|REG_URL|REG_DESC"
        printf '[0|%s]\n' "$header" > "$REGISTRY_FILE"
    fi
}

# Get OS type with WSL detection and case-insensitivity
get_os() {
    local sys_name=$(uname -s | tr '[:upper:]' '[:lower:]')
    local os_out=""
    case "$sys_name" in
        linux*)   os_out="Linux" ;;
        darwin*)  os_out="MacOS-Darwin" ;;
        cygwin*)  os_out="Windows-CYGWIN" ;;
        mingw*)   os_out="Windows-MINGW" ;;
        msys*)    os_out="Windows-MSYS" ;;
        *)        os_out="$(uname -s)" ;;
    esac

    # WSL Detection (check /proc/version or uname -r)
    if grep -qi "microsoft" /proc/version 2>/dev/null || uname -r | grep -qi "microsoft"; then
        os_out="${os_out}-WSL"
    fi
    echo "$os_out"
}

# Collect environment metadata
get_env_metadata() {
    local metadata=""
    
    # OS/Distro
    local distro="Unknown"
    if [[ -f /etc/os-release ]]; then
        distro=$(grep PRETTY_NAME /etc/os-release | cut -d'=' -f2 | tr -d '"')
    fi
    metadata+="OS_Distro: $distro\n"
    
    # Host (Model)
    local host="Unknown"
    if [[ -f /sys/class/dmi/id/product_name ]]; then
        host=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "Unknown")
    fi
    metadata+="Host_Model: $host\n"
    
    # OS Name (uname -o)
    metadata+="OS_Name: $(uname -o 2>/dev/null || echo "Unknown")\n"
    
    # Kernel
    metadata+="Kernel: $(uname -r 2>/dev/null || echo "Unknown")\n"
    
    # Shell
    metadata+="Shell: $(basename "$SHELL" 2>/dev/null || echo "Unknown")\n"
    
    # Machine Architecture
    metadata+="Arch: $(uname -m 2>/dev/null || echo "Unknown")\n"
    
    # CPU
    local cpu=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | sed 's/^[ \t]*//' 2>/dev/null || echo "Unknown")
    metadata+="CPU: $cpu\n"
    
    # GPU
    local gpu="Unknown"
    if command -v lspci &> /dev/null; then
        gpu=$(lspci | grep -i vga | cut -d':' -f3 | sed 's/^[ \t]*//' | head -1 2>/dev/null || echo "Unknown")
    fi
    metadata+="GPU: $gpu\n"
    
    echo -e "$metadata"
}

# Initialize bare git repository
cmd_init() {
    local repo_path="$1"
    local setup_name="$2"
    local dotfiles_folder="$3"
    
    if [[ -z "$repo_path" ]]; then
        die "Usage: $0 init <repo_path> <setup_name> <dotfiles_folder>"
    fi
    
    if [[ -z "$setup_name" ]]; then
        setup_name="$(hostname)-$(get_os)"
    fi
    
    if [[ -z "$dotfiles_folder" ]]; then
        dotfiles_folder="$HOME"
    fi
    
    # Create bare repository
    if [[ -d "$repo_path" ]]; then
        warn "Repository path already exists: $repo_path"
        if [[ -t 0 ]]; then
            read -p "Do you want to continue? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                die "Initialization cancelled"
            fi
        else
            info "Non-interactive session, skipping directory check."
        fi
    fi
    
    mkdir -p "$repo_path" || die "Failed to create repository directory"
    
    # Track if we created the directory to rollback if needed
    local repo_created=false
    if [[ -d "$repo_path" ]]; then
        repo_created=true
    fi

    if ! git init --bare "$repo_path" &>/dev/null; then
        [[ "$repo_created" == "true" ]] && rm -rf "$repo_path"
        die "Failed to initialize git repository at $repo_path"
    fi
    success "Bare git repository initialized at $repo_path"
    
    # Add to configuration
    init_config
    local os_type=$(get_os)
    local setup_branch="$setup_name"
    
    # Update config with new setup
    printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$(_get_timestamp_iso)" "dots.sh" "$USER" "$PWD" "init" "$VERSION" \
        "$setup_name" "$os_type" "$dotfiles_folder" "$repo_path" "$setup_branch" >> "$CONFIG_FILE"
    
    # Update row count in header
    local count=$(grep -v "^\[" "$CONFIG_FILE" | wc -l)
    sed -i "1s/\[[0-9]*|/[$count|/" "$CONFIG_FILE"
    
    success "Setup '$setup_name' registered (OS: $os_type, Folder: $dotfiles_folder)"
    
    # Create alias helper
    info "To use this dotfile repository, add this alias to your shell config:"
    echo ""
    echo "    alias dotfiles='git --git-dir=$repo_path --work-tree=$dotfiles_folder'"
    echo ""
}

# Clone existing bare repository
cmd_clone() {
    local remote_url="$1"
    local repo_path="$2"
    local setup_name="$3"
    local dotfiles_folder="$4"
    
    if [[ -z "$remote_url" ]] || [[ -z "$repo_path" ]]; then
        die "Usage: $0 clone <remote_url> <repo_path> [setup_name] [dotfiles_folder]"
    fi
    
    if [[ -z "$setup_name" ]]; then
        setup_name="$(hostname)-$(get_os)"
    fi
    
    if [[ -z "$dotfiles_folder" ]]; then
        dotfiles_folder="$HOME"
    fi
    
    # Clone as bare repository
    if ! git clone --bare "$remote_url" "$repo_path"; then
        die "Failed to clone repository from $remote_url"
    fi
    success "Repository cloned to $repo_path"
    
    # Add to configuration
    init_config
    local os_type=$(get_os)
    local setup_branch="$setup_name"
    
    # Update config with new setup
    printf '%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$(_get_timestamp_iso)" "dots.sh" "$USER" "$PWD" "clone" "$VERSION" \
        "$setup_name" "$os_type" "$dotfiles_folder" "$repo_path" "$setup_branch" >> "$CONFIG_FILE"
    
    # Update row count in header
    local count=$(grep -v "^\[" "$CONFIG_FILE" | wc -l)
    sed -i "1s/\[[0-9]*|/[$count|/" "$CONFIG_FILE"
    
    success "Setup '$setup_name' registered"
    
    # Create alias helper
    info "To use this dotfile repository, add this alias to your shell config:"
    echo ""
    echo "    alias dotfiles='git --git-dir=$repo_path --work-tree=$dotfiles_folder'"
    echo ""
}

# List all configured setups with rich metadata
cmd_list() {
    init_config
    
    local count=$(grep -v "^\[" "$CONFIG_FILE" | wc -l)
    
    if [[ "$count" -eq 0 ]]; then
        warn "No setups configured yet. Use 'dots init' or 'dots clone' to get started."
        return
    fi
    
    info "Registered Setups Dashboard"
    echo ""
    
    # Process each setup (skip header)
    grep -v "^\[" "$CONFIG_FILE" | while IFS='|' read -r timestamp script user pwd call version name os folder repo branch; do
        # UI Borders
        echo -e "${BLUE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        printf "${BLUE}║${NC}  ${GREEN}%-74s${NC}  ${BLUE}║${NC}\n" "SETUP: $name"
        echo -e "${BLUE}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
        
        # Environment Info
        printf "${BLUE}║${NC}  ${YELLOW}%-15s${NC} %-58s ${BLUE}║${NC}\n" "OS Family:" "$os"
        
        # Try to get live metadata if it's the current machine
        local current_os=$(get_os)
        if [[ "$current_os" == *"$os"* ]] || [[ "$os" == *"$current_os"* ]]; then
            local meta=$(get_env_metadata)
            local distro=$(echo -e "$meta" | grep "OS_Distro" | cut -d':' -f2- | xargs)
            local kernel=$(echo -e "$meta" | grep "Kernel" | cut -d':' -f2- | xargs)
            local cpu=$(echo -e "$meta" | grep "CPU" | cut -d':' -f2- | xargs | cut -c1-58)
            local gpu=$(echo -e "$meta" | grep "GPU" | cut -d':' -f2- | xargs | cut -c1-58)
            
            printf "${BLUE}║${NC}  ${YELLOW}%-15s${NC} %-58s ${BLUE}║${NC}\n" "Distro:" "$distro"
            printf "${BLUE}║${NC}  ${YELLOW}%-15s${NC} %-58s ${BLUE}║${NC}\n" "Kernel:" "$kernel"
            printf "${BLUE}║${NC}  ${YELLOW}%-15s${NC} %-58s ${BLUE}║${NC}\n" "CPU:" "$cpu"
            [[ "$gpu" != "Unknown" ]] && printf "${BLUE}║${NC}  ${YELLOW}%-15s${NC} %-58s ${BLUE}║${NC}\n" "GPU:" "$gpu"
        fi
        
        echo -e "${BLUE}╟──────────────────────────────────────────────────────────────────────────────╢${NC}"
        
        # Git Info
        printf "${BLUE}║${NC}  ${YELLOW}%-15s${NC} %-58s ${BLUE}║${NC}\n" "Work Tree:" "$folder"
        printf "${BLUE}║${NC}  ${YELLOW}%-15s${NC} %-58s ${BLUE}║${NC}\n" "Repo Path:" "$repo"
        printf "${BLUE}║${NC}  ${YELLOW}%-15s${NC} %-58s ${BLUE}║${NC}\n" "Branch:" "$branch"
        
        # Remotes
        if [[ -d "$repo" ]]; then
            local remotes=$(git --git-dir="$repo" remote -v 2>/dev/null | awk '{print $1 " (" $2 ")"}' | sort -u)
            if [[ -n "$remotes" ]]; then
                while read -r remote_line; do
                    printf "${BLUE}║${NC}  ${YELLOW}%-15s${NC} %-58s ${BLUE}║${NC}\n" "Remote:" "$remote_line"
                done <<< "$remotes"
            fi
        fi
        
        echo -e "${BLUE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
    done
}

# List bash-related files for the selected setup.
# Scans the HEAD of the repository for files starting with '.bash'.
cmd_bash_list() {
    local setup_name=$(_resolve_setup_name)
    _git_run "$setup_name" ls-tree -r --name-only HEAD | grep -E "^\.bash" | while read -r item; do
        echo -e "  • ${YELLOW}$item${NC}"
    done
}

# Show detailed information about the selected setup.
# Displays OS metadata, local/remote branch status, and tracking information.
cmd_setup_show() {
    local setup_name=$(_resolve_setup_name)
    
    init_config
    
    # Fetch setup configuration
    local setup_line=$(grep -F "|$setup_name|" "$CONFIG_FILE" | head -n 1)
    if [[ -z "$setup_line" ]]; then
        die "Setup '$setup_name' not found"
    fi
    
    # Parse CSV fields (1-based: 7:name, 8:os, 9:folder, 10:repo, 11:branch)
    local os=$(echo "$setup_line" | cut -d'|' -f8)
    local folder=$(echo "$setup_line" | cut -d'|' -f9)
    local repo=$(echo "$setup_line" | cut -d'|' -f10)
    local branch=$(echo "$setup_line" | cut -d'|' -f11)
    
    # Display setup information
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Setup: ${NC}${YELLOW}$setup_name${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${BLUE}Operating System:${NC}  $os"
    echo -e "${BLUE}Work Tree:${NC}         $folder"
    echo -e "${BLUE}Repository:${NC}        $repo"
    echo -e "${BLUE}Branch:${NC}            $branch"
    echo ""
    
    # Check if repository exists
    if [[ ! -d "$repo" ]]; then
        warn "Repository path does not exist"
        echo ""
        return
    fi
    
    # Check repository status
    info "Repository Status:"
    echo ""
    
    # Check if branch exists locally
    if git --git-dir="$repo" rev-parse --verify "$branch" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} Local branch exists: $branch"
        
        # Get last commit info
        local last_commit=$(git --git-dir="$repo" log -1 --format="%h - %s (%cr)" "$branch" 2>/dev/null || echo "No commits")
        echo -e "  ${BLUE}Last commit:${NC} $last_commit"
    else
        echo -e "  ${YELLOW}⚠${NC} Local branch does not exist: $branch"
    fi
    
    # Check remote tracking
    local remotes=$(git --git-dir="$repo" remote 2>/dev/null || echo "")
    if [[ -n "$remotes" ]]; then
        echo ""
        echo -e "${BLUE}Remotes:${NC}"
        while IFS= read -r remote; do
            local remote_url=$(git --git-dir="$repo" remote get-url "$remote" 2>/dev/null || echo "Unknown")
            echo -e "  • ${YELLOW}$remote${NC}: $remote_url"
            
            # Check if branch exists on remote
            if git --git-dir="$repo" ls-remote --heads "$remote" "$branch" 2>/dev/null | grep -q "$branch"; then
                echo -e "    ${GREEN}✓${NC} Remote branch exists: $remote/$branch"
            else
                echo -e "    ${YELLOW}⚠${NC} Remote branch does not exist: $remote/$branch"
            fi
        done <<< "$remotes"
    else
        echo ""
        warn "No remotes configured"
    fi
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo ""
}

# Initialize bash files from remote for the selected setup.
# This will back up existing files to ~/.dotfailes-backups/ before overwriting.
cmd_bash_init() {
    local setup_name=$(_resolve_setup_name)

    init_config

    local repo_path=$(_get_setup_field "$setup_name" 10)
    local work_tree=$(_get_setup_field "$setup_name" 9)
    local setup_branch=$(_get_setup_field "$setup_name" 11)

    if [[ -z "$repo_path" ]]; then
        die "Setup '$setup_name' not found"
    fi

    if [[ -z "$work_tree" ]]; then
        die "Setup '$setup_name' has no work tree configured"
    fi

    if [[ -z "$setup_branch" ]]; then
        setup_branch="$setup_name"
        _update_setup_field "$setup_name" 11 "$setup_branch"
    fi

    if ! git --git-dir="$repo_path" remote get-url origin >/dev/null 2>&1; then
        die "Remote 'origin' not configured for setup '$setup_name'"
    fi

    local backup_root="$work_tree/.dotfailes-backups"
    local backup_stamp
    backup_stamp=$(date -u +"%Y%m%dT%H%M%SZ")
    local backup_dir="$backup_root/bash-init-$backup_stamp"
    local backup_created=0

    mkdir -p "$backup_root"

    for bash_item in .bashrc .bash_profile .bash_aliases .bashrc.d; do
        if [[ -e "$work_tree/$bash_item" ]]; then
            if [[ "$backup_created" -eq 0 ]]; then
                mkdir -p "$backup_dir"
                backup_created=1
            fi
            cp -a "$work_tree/$bash_item" "$backup_dir/" || warn "Failed to back up $bash_item"
        fi
    done

    if [[ "$backup_created" -eq 1 ]]; then
        success "Backed up bash files to $backup_dir"
    fi

    local source_branch="origin/$setup_branch"
    if [[ -z $(git --git-dir="$repo_path" ls-remote --heads origin "$setup_branch") ]]; then
        warn "Branch '$setup_branch' not found on origin. Falling back to origin/main."
        source_branch="origin/main"
        info "Fetching latest from origin main..."
        git --git-dir="$repo_path" fetch origin main || warn "Fetch failed or no changes"
    else
        info "Fetching latest from origin $setup_branch..."
        git --git-dir="$repo_path" fetch origin "$setup_branch" || warn "Fetch failed or no changes"
    fi

    info "Checking out bash files from $source_branch"
    git --git-dir="$repo_path" --work-tree="$work_tree" checkout "$source_branch" -- \
        .bashrc .bash_profile .bash_aliases .bashrc.d || die "Checkout failed"

    success "Bash files initialized in $work_tree"
}

# Reload bash files from remote for the selected setup (no backups).
# Warning: This will overwrite local changes to bash files without backing them up.
cmd_bash_reload() {
    local setup_name=$(_resolve_setup_name)

    init_config

    local repo_path
    local work_tree
    local setup_branch

    local repo_path=$(_get_setup_field "$setup_name" 10)
    local work_tree=$(_get_setup_field "$setup_name" 9)
    local setup_branch=$(_get_setup_field "$setup_name" 11)

    if [[ -z "$repo_path" ]]; then
        die "Setup '$setup_name' not found"
    fi

    if [[ -z "$work_tree" ]]; then
        die "Setup '$setup_name' has no work tree configured"
    fi

    if [[ -z "$setup_branch" ]]; then
        setup_branch="$setup_name"
        _update_setup_field "$setup_name" 11 "$setup_branch"
    fi

    if ! git --git-dir="$repo_path" remote get-url origin >/dev/null 2>&1; then
        die "Remote 'origin' not configured for setup '$setup_name'"
    fi

    local source_branch="origin/$setup_branch"
    if [[ -z $(git --git-dir="$repo_path" ls-remote --heads origin "$setup_branch") ]]; then
        warn "Branch '$setup_branch' not found on origin. Falling back to origin/main."
        source_branch="origin/main"
        info "Fetching latest from origin main..."
        git --git-dir="$repo_path" fetch origin main || warn "Fetch failed or no changes"
    else
        info "Fetching latest from origin $setup_branch..."
        git --git-dir="$repo_path" fetch origin "$setup_branch" || warn "Fetch failed or no changes"
    fi

    info "Reloading bash files from $source_branch"
    git --git-dir="$repo_path" --work-tree="$work_tree" checkout "$source_branch" -- \
        .bashrc .bash_profile .bash_aliases .bashrc.d || die "Checkout failed"

    success "Bash files reloaded in $work_tree"
}

# Add a remote to the selected setup.
# Usage: dots add-remote <remote_name> <remote_url>
cmd_add_remote() {
    local setup_name=$(_resolve_setup_name)
    local remote_name="$1"
    local remote_url="$2"
    
    if [[ -z "$remote_name" ]] || [[ -z "$remote_url" ]]; then
        die "Usage: $0 add-remote <remote_name> <remote_url>"
    fi
    
    init_config
    
    # Get repository path for setup
    local setup_line=$(grep -F "|$setup_name|" "$CONFIG_FILE" | head -n 1)
    local repo_path=$(echo "$setup_line" | cut -d'|' -f10)
    
    if [[ -z "$repo_path" ]]; then
        die "Setup '$setup_name' not found"
    fi
    
    # Add remote
    git --git-dir="$repo_path" remote add "$remote_name" "$remote_url" 2>/dev/null || \
        git --git-dir="$repo_path" remote set-url "$remote_name" "$remote_url"
    
    success "Remote '$remote_name' added to setup '$setup_name'"
}

# List remotes for the selected setup.
cmd_list_remotes() {
    local setup_name=$(_resolve_setup_name)
    
    init_config
    
    local setup_line=$(grep -F "|$setup_name|" "$CONFIG_FILE" | head -n 1)
    local repo_path=$(echo "$setup_line" | cut -d'|' -f10)
    
    if [[ -z "$repo_path" ]]; then
        die "Setup '$setup_name' not found"
    fi
    
    info "Remotes for setup '$setup_name':"
    git --git-dir="$repo_path" remote -v
}

# List registered dotfiles repositories
cmd_registry_list() {
    init_config

    local count=$(grep -v "^\[" "$REGISTRY_FILE" | wc -l)

    if [[ "$count" -eq 0 ]]; then
        warn "No registry entries configured"
        return
    fi

    info "Registered repositories:"
    echo ""
    # Skip header and parse registry CSV (Field 7:name, 8:url, 9:desc)
    grep -v "^\[" "$REGISTRY_FILE" | while IFS='|' read -r timestamp script user pwd call version name url desc; do
        echo -e "  • ${YELLOW}$name${NC}"
        echo -e "    URL: $url"
        echo -e "    Description: ${desc:-N/A}"
        echo ""
    done
}

# Use a registered repository for the selected setup's remote.
# Usage: dots registry:use <registry_name> [remote_name]
cmd_registry_use() {
    local registry_name="$1"
    local remote_name="${2:-origin}"

    if [[ -z "$registry_name" ]]; then
        die "Usage: $0 registry:use <registry_name> [remote_name]"
    fi

    init_config

    local registry_line=$(grep -F "|$registry_name|" "$REGISTRY_FILE" | head -n 1)

    if [[ -z "$registry_line" ]]; then
        die "Registry entry '$registry_name' not found"
    fi

    # Field 8 is URL
    local registry_url=$(echo "$registry_line" | cut -d'|' -f8)

    local setup_name=$(_resolve_setup_name)
    local setup_line=$(grep -F "|$setup_name|" "$CONFIG_FILE" | head -n 1)
    local repo_path=$(echo "$setup_line" | cut -d'|' -f10)

    if [[ -z "$repo_path" ]]; then
        die "Setup '$setup_name' not found"
    fi

    if [[ -z "$registry_url" ]]; then
        die "Registry entry '$registry_name' has no url"
    fi

    if git --git-dir="$repo_path" remote get-url "$remote_name" >/dev/null 2>&1; then
        git --git-dir="$repo_path" remote set-url "$remote_name" "$registry_url"
    else
        git --git-dir="$repo_path" remote add "$remote_name" "$registry_url"
    fi

    success "Registry '$registry_name' applied to setup '$setup_name' (remote: $remote_name)"
}

# Remove a remote from the selected setup.
# Usage: dots remove-remote <remote_name>
cmd_remove_remote() {
    local setup_name=$(_resolve_setup_name)
    local remote_name="$1"
    
    if [[ -z "$remote_name" ]]; then
        die "Usage: $0 remove-remote <remote_name>"
    fi
    
    init_config
    
    local repo_path=$(_get_setup_field "$setup_name" 10)
    
    if [[ -z "$repo_path" ]]; then
        die "Setup '$setup_name' not found"
    fi
    
    git --git-dir="$repo_path" remote remove "$remote_name"
    success "Remote '$remote_name' removed from setup '$setup_name'"
}

# Ensure the setup's branch exists and is pushed to a remote.
# Usage: dots branch-ensure [remote_name]
cmd_branch_ensure() {
    local setup_name=$(_resolve_setup_name)
    local remote_name="${1:-origin}"

    init_config
    
    local repo_path=$(_get_setup_field "$setup_name" 10)
    local work_tree=$(_get_setup_field "$setup_name" 9)
    local setup_branch=$(_get_setup_field "$setup_name" 11)

    if [[ -z "$repo_path" ]]; then
        die "Setup '$setup_name' not found"
    fi

    if [[ -z "$work_tree" ]]; then
        die "Setup '$setup_name' has no work tree configured"
    fi

    if [[ -z "$setup_branch" ]]; then
        setup_branch="$setup_name"
        _update_setup_field "$setup_name" 11 "$setup_branch"
    fi

    info "Ensuring branch '$setup_branch' for setup '$setup_name'"
    git --git-dir="$repo_path" --work-tree="$work_tree" checkout -B "$setup_branch" || die "Branch checkout failed"

    if ! git --git-dir="$repo_path" rev-parse --verify HEAD >/dev/null 2>&1; then
        local git_user_name
        local git_user_email
        git_user_name=$(git --git-dir="$repo_path" config user.name || true)
        git_user_email=$(git --git-dir="$repo_path" config user.email || true)

        if [[ -z "$git_user_name" || -z "$git_user_email" ]]; then
            die "No commits exist and git user.name/user.email are not set. Configure them or create a commit before pushing."
        fi

        info "No commits found. Creating an empty commit for setup branch."
        git --git-dir="$repo_path" --work-tree="$work_tree" commit --allow-empty -m "Initialize setup branch $setup_branch" || die "Empty commit failed"
    fi

    git --git-dir="$repo_path" --work-tree="$work_tree" push -u "$remote_name" "$setup_branch" || die "Push failed"

    success "Branch '$setup_branch' is set for setup '$setup_name' on $remote_name"
}

# Sync the selected setup with its remote (performs both pull and push).
# Usage: dots sync [remote_name] [branch_override]
cmd_sync() {
    local setup_name=$(_resolve_setup_name)
    local remote_name="${1:-origin}"
    local branch_override="$2"
    
    init_config
    
    local repo_path=$(_get_setup_field "$setup_name" 10)
    local work_tree=$(_get_setup_field "$setup_name" 9)
    local setup_branch=$(_get_setup_field "$setup_name" 11)
    
    if [[ -z "$repo_path" ]]; then
        die "Setup '$setup_name' not found"
    fi

    if [[ -z "$setup_branch" ]]; then
        setup_branch="$setup_name"
        _update_setup_field "$setup_name" 11 "$setup_branch"
    fi

    local branch="${branch_override:-$setup_branch}"
    
    info "Syncing setup '$setup_name' with remote '$remote_name'..."
    
    # Pull changes
    info "Pulling changes from $remote_name/$branch..."
    git --git-dir="$repo_path" --work-tree="$work_tree" pull "$remote_name" "$branch" || warn "Pull failed or no changes"
    
    # Push changes
    info "Pushing changes to $remote_name/$branch..."
    git --git-dir="$repo_path" --work-tree="$work_tree" push "$remote_name" "$branch" || warn "Push failed or no changes"
    
    success "Sync completed"
}

# Show the git status for the selected setup.
# Provides a summary of changed, untracked, and staged files within the work-tree.
cmd_status() {
    local setup_name=$(_resolve_setup_name)
    
    init_config
    
    local setup_line=$(grep -F "|$setup_name|" "$CONFIG_FILE" | head -n 1)
    if [[ -z "$setup_line" ]]; then
        die "Setup '$setup_name' not found in configuration."
    fi
    
    info "Status for setup '$setup_name':"
    _git_run "$setup_name" status
}

# Add files to the selected setup's repository.
# Proxies arguments directly to 'git add'.
cmd_add() {
    local setup_name=$(_resolve_setup_name)
    _git_run "$setup_name" add "$@"
}

# Commit changes for the selected setup with automated rich metadata.
# Captures environment info (OS, CPU, GPU) and adds it to the commit footer.
cmd_commit() {
    local setup_name=$(_resolve_setup_name)
    
    init_config
    
    local repo_path=$(_get_setup_field "$setup_name" 10)
    local work_tree=$(_get_setup_field "$setup_name" 9)
    
    # 1. Identify files
    local files=$(git --git-dir="$repo_path" --work-tree="$work_tree" status --porcelain | awk '{print $2}' | xargs | sed 's/ /, /g')
    if [[ -z "$files" ]]; then
        warn "No changes to commit"
        return
    fi
    
    # 2. Determine Type & Scope
    local type="fix"
    if git --git-dir="$repo_path" --work-tree="$work_tree" status --porcelain | grep -q "^??"; then
        type="feat"
    fi
    local scope=$(basename "$SHELL")
    
    # 3. Determine Subject
    local subject="update $files"
    
    # 4. Handle User Message (Body)
    local user_msg=""
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "-m" ]]; then
            user_msg="$2"
            shift 2
        else
            shift
        fi
    done
    
    # 5. Determine Footer (Metadata changes)
    local meta_file="${repo_path}/info/last_metadata"
    local current_meta=$(get_env_metadata)
    local footer=""
    
    if [[ -f "$meta_file" ]]; then
        local old_meta=$(cat "$meta_file")
        # Compare line by line
        while IFS= read -r line; do
            local key=$(echo "$line" | cut -d':' -f1)
            local old_val=$(echo "$old_meta" | grep "^$key:" | cut -d':' -f2- | sed 's/^[ \t]*//')
            local new_val=$(echo "$line" | cut -d':' -f2- | sed 's/^[ \t]*//')
            
            if [[ "$old_val" != "$new_val" && -n "$old_val" ]]; then
                footer+="${key}: ${old_val} -> ${new_val}\n"
            fi
        done <<< "$current_meta"
    fi
    
    # Save current metadata for next time
    mkdir -p "$(dirname "$meta_file")"
    echo -e "$current_meta" > "$meta_file"
    
    # 6. Build Message
    local commit_msg="${type}(${scope}): ${subject}"
    if [[ -n "$user_msg" ]]; then
        commit_msg+="\n\n${user_msg}"
    fi
    if [[ -n "$footer" ]]; then
        commit_msg+="\n\n${footer}"
    fi
    
    # 7. Execute Commit
    info "Committing with message: ${type}(${scope}): ${subject}"
    git --git-dir="$repo_path" --work-tree="$work_tree" commit -m "$(echo -e "$commit_msg")"
}

# Push changes for the selected setup.
# Proxies arguments directly to 'git push'.
cmd_push() {
    local setup_name=$(_resolve_setup_name)
    _git_run "$setup_name" push "$@"
}

# Pull changes for the selected setup.
# Proxies arguments directly to 'git pull'.
cmd_pull() {
    local setup_name=$(_resolve_setup_name)
    _git_run "$setup_name" pull "$@"
}

# Show differences for the selected setup.
# Proxies arguments directly to 'git diff'.
cmd_diff() {
    local setup_name=$(_resolve_setup_name)
    _git_run "$setup_name" diff "$@"
}

# Merge a branch into a target branch for the selected setup.
# Usage: dots merge [source_branch] [target_branch] [remote_name]
cmd_merge() {
    local setup_name=$(_resolve_setup_name)
    local source_branch="${1:-}"
    local target_branch="${2:-main}"
    local remote_name="${3:-origin}"

    init_config
    
    local repo_path=$(_get_setup_field "$setup_name" 10)
    local work_tree=$(_get_setup_field "$setup_name" 9)
    local setup_branch=$(_get_setup_field "$setup_name" 11)

    if [[ -z "$repo_path" ]]; then
        die "Setup '$setup_name' not found"
    fi

    if [[ -z "$work_tree" ]]; then
        die "Setup '$setup_name' has no work tree configured"
    fi

    if [[ -z "$source_branch" ]]; then
        source_branch="$setup_branch"
    fi

    if [[ -z "$source_branch" ]]; then
        source_branch="$setup_name"
    fi

    info "Merging $source_branch into $target_branch for setup '$setup_name'"
    info "Source branch will be kept intact after merge"
    
    # Fetch latest from remote
    info "Fetching latest from $remote_name..."
    git --git-dir="$repo_path" fetch "$remote_name" || warn "Fetch failed"

    # Check out target branch (use clean strategy to handle untracked files)
    info "Checking out $target_branch..."
    git --git-dir="$repo_path" --work-tree="$work_tree" checkout -f "$target_branch" || die "Failed to checkout $target_branch"

    # Merge source into target
    info "Merging $remote_name/$source_branch into $target_branch..."
    if git --git-dir="$repo_path" --work-tree="$work_tree" merge "$remote_name/$source_branch" --allow-unrelated-histories -m "Merge $source_branch into $target_branch"; then
        success "Merge completed successfully"
        # Push merged changes
        info "Pushing merged changes to $remote_name/$target_branch..."
        git --git-dir="$repo_path" --work-tree="$work_tree" push "$remote_name" "$target_branch" || warn "Push failed"
        success "Changes pushed to remote"
        info "Source branch '$source_branch' remains intact on remote"
    else
        error "Merge conflict detected"
        info "Resolve conflicts in $work_tree and run:"
        echo "  dotfiles add <conflicted_file>"
        echo "  dotfiles commit -m \"Merge $source_branch into $target_branch\""
        echo "  dotfiles push"
        exit 1
    fi
}

# Ensure the selected setup has a remote tracking branch.
# Usage: dots ensure-remote-branch [remote_name]
cmd_ensure_remote_branch() {
    local setup_name=$(_resolve_setup_name)
    local remote_name="${1:-origin}"
    
    init_config
    
    if [[ -z "$setup_name" ]]; then
        die "No setups configured yet"
    fi
    
    local repo_path=$(_get_setup_field "$setup_name" 10)
    local work_tree=$(_get_setup_field "$setup_name" 9)
    local setup_branch=$(_get_setup_field "$setup_name" 11)
    
    if [[ -z "$repo_path" ]]; then
        die "Setup '$setup_name' not found"
    fi
    
    if [[ -z "$work_tree" ]]; then
        die "Setup '$setup_name' has no work tree configured"
    fi
    
    if [[ -z "$setup_branch" ]]; then
        setup_branch="$setup_name"
        _update_setup_field "$setup_name" 11 "$setup_branch"
    fi
    
    if ! git --git-dir="$repo_path" remote get-url "$remote_name" >/dev/null 2>&1; then
        die "Remote '$remote_name' not configured for setup '$setup_name'"
    fi
    
    info "Ensuring remote branch '$setup_branch' for setup '$setup_name' on remote '$remote_name'"
    
    # Check if remote branch exists
    if git --git-dir="$repo_path" ls-remote --heads "$remote_name" "$setup_branch" | grep -q "$setup_branch"; then
        success "Remote branch '$setup_branch' already exists on $remote_name"
    else
        info "Remote branch '$setup_branch' does not exist. Creating and pushing..."
        
        # Ensure local branch exists
        if ! git --git-dir="$repo_path" rev-parse --verify "$setup_branch" >/dev/null 2>&1; then
            info "Local branch '$setup_branch' does not exist. Creating from current HEAD..."
            git --git-dir="$repo_path" --work-tree="$work_tree" checkout -B "$setup_branch" || die "Failed to create local branch"
        else
            info "Checking out local branch '$setup_branch'..."
            git --git-dir="$repo_path" --work-tree="$work_tree" checkout "$setup_branch" || die "Failed to checkout branch"
        fi
        
        # Ensure there's at least one commit
        if ! git --git-dir="$repo_path" rev-parse --verify HEAD >/dev/null 2>&1; then
            local git_user_name
            local git_user_email
            git_user_name=$(git --git-dir="$repo_path" config user.name || echo "")
            git_user_email=$(git --git-dir="$repo_path" config user.email || echo "")
            
            if [[ -z "$git_user_name" || -z "$git_user_email" ]]; then
                die "No commits exist and git user.name/user.email are not set. Configure them or create a commit before pushing."
            fi
            
            info "No commits found. Creating an empty commit..."
            git --git-dir="$repo_path" --work-tree="$work_tree" commit --allow-empty -m "Initialize setup branch $setup_branch" || die "Failed to create initial commit"
        fi
        
        # Push to remote
        info "Pushing branch '$setup_branch' to $remote_name..."
        git --git-dir="$repo_path" --work-tree="$work_tree" push -u "$remote_name" "$setup_branch" || die "Failed to push branch to remote"
        success "Remote branch '$setup_branch' created and pushed to $remote_name"
    fi
    
    success "Setup '$setup_name' now has remote branch '$setup_branch' on $remote_name"
}

# Show help
cmd_help() {
    cat <<EOF
dots - Dotfile management using bare git repositories

USAGE:
    $0 <command> [arguments]

COMMANDS:
    init <repo_path> [setup_name] [dotfiles_folder]
        Initialize a new bare git repository for dotfile management
        
    clone <remote_url> <repo_path> [setup_name] [dotfiles_folder]
        Clone an existing dotfile repository
        
    list
        List all configured setups
 
    rm <setup_name> [--purge]
        Remove a setup from configuration
        Use --purge to also delete the bare git repository

    rename <old_name> <new_name>
        Rename a setup in the configuration
        Also renames the local branch if it matches the old name

    setup:show
        Show detailed information about the selected setup

    bash:list
        List bash-related files for the selected setup

    bash:init
        Initialize bash files from remote for the selected setup
        Backs up existing files to ~/.dotfailes-backups/

    bash:reload
        Reload bash files from remote for a setup (no backups)
        
    add-remote <remote_name> <remote_url>
        Add a remote to the selected setup
        
    list-remotes
        List remotes for the selected setup
        
    remove-remote <remote_name>
        Remove a remote from the selected setup

    registry:list
        List registered dotfiles repositories

    registry:use <registry_name> [remote_name]
        Use a registered repository for the selected setup's remote

    branch-ensure [remote_name]
        Ensure setup branch exists and is pushed to remote
        
    ensure-remote-branch [remote_name]
        Ensure selected setup has a remote branch
        
    merge [source_branch] [target_branch] [remote_name]
        Merge source branch into target branch (default: setup branch → main)
        Source branch is kept intact after merge
        
    sync [remote_name] [branch]
        Sync the selected setup with remote (pull and push)
        
    status
        Show git status for the selected setup
        
    add [git_args]
        Add files to tracking (proxies to git add)
        
    commit [git_args]
        Commit changes with rich metadata (proxies to git commit)
        
    push [git_args]
        Push changes (proxies to git push)
        
    pull [git_args]
        Pull changes (proxies to git pull)
        
    diff [git_args]
        Show differences (proxies to git diff)
        
    help
        Show this help message

OPTIONS:
    --setup <name>
        Specify which setup to use for the command.
        Defaults to the first setup in ~/.dotfailes/config.json.

EXAMPLES:
    # Initialize new dotfile repository
    $0 init ~/.dotfiles my-laptop ~/
    
    # Check status of default setup
    $0 status

    # Check status of specific setup
    $0 --setup my-laptop status

    # Add and commit files to default setup
    $0 add .bashrc
    $0 commit -m "Update bashrc"

    # Sync specific setup
    $0 --setup my-laptop sync origin main

CONFIGURATION:
    Configuration is stored in: $CONFIG_FILE
    
    Each setup tracks:
    - Setup name
    - Operating system
    - Dotfiles folder (work tree)
    - Repository path (bare git repo)

EOF
}

# Remove a setup from configuration.
# Usage: dots rm <setup_name> [--purge]
# By default, only the entry in config.json is removed.
# Use --purge to also delete the bare git repository.
cmd_rm() {
    local setup_to_remove="$1"
    local purge=false
    
    if [[ "$2" == "--purge" ]]; then
        purge=true
    fi

    if [[ -z "$setup_to_remove" ]]; then
        die "Usage: $0 rm <setup_name> [--purge]"
    fi

    init_config

    # Verify that the setup exists (Field 7 is name)
    local setup_line=$(grep -F "|$setup_to_remove|" "$CONFIG_FILE" | head -n 1)
    if [[ -z "$setup_line" ]]; then
        die "Setup '$setup_to_remove' not found in configuration."
    fi

    # Capture the repository path before removal (Field 10 is repo)
    local repo_path=$(echo "$setup_line" | cut -d'|' -f10)

    # Request user confirmation
    warn "Are you sure you want to remove setup '$setup_to_remove'? [y/N]"
    if [[ -t 0 ]]; then
        read -r response
    else
        response="y"
        info "Non-interactive session detected, assuming yes."
    fi
    if [[ ! "$response" =~ ^[yY]$ ]]; then
        die "Operation cancelled."
    fi

    # Remove the entry from config.csv
    local tmp_config=$(mktemp)
    grep -vF "|$setup_to_remove|" "$CONFIG_FILE" > "$tmp_config" && mv "$tmp_config" "$CONFIG_FILE"
    
    # Update row count in header
    local count=$(grep -v "^\[" "$CONFIG_FILE" | wc -l)
    sed -i "1s/\[[0-9]*|/[$count|/" "$CONFIG_FILE"

    success "Setup '$setup_to_remove' removed from configuration."

    # Handle repository purging
    if [[ "$purge" == true ]]; then
        if [[ -d "$repo_path" ]]; then
            info "Purging repository at $repo_path..."
            rm -rf "$repo_path"
            success "Repository deleted."
        else
            warn "Repository path '$repo_path' not found or is not a directory. Skipping purge."
        fi
    fi
}

# Rename a setup in the configuration and optionally in the repository.
# Usage: dots rename <old_name> <new_name>
cmd_rename() {
    local old_name="$1"
    local new_name="$2"
    
    if [[ -z "$old_name" ]] || [[ -z "$new_name" ]]; then
        die "Usage: $0 rename <old_name> <new_name>"
    fi
    
    init_config
    
    # 1. Verify old setup exists
    local setup_line=$(grep -F "|$old_name|" "$CONFIG_FILE" | head -n 1)
    if [[ -z "$setup_line" ]]; then
        die "Setup '$old_name' not found."
    fi
    
    # 2. Verify new name doesn't exist
    if grep -qF "|$new_name|" "$CONFIG_FILE"; then
        die "Setup '$new_name' already exists."
    fi
    
    # 3. Get repo path and current branch
    local repo_path=$(echo "$setup_line" | cut -d'|' -f10)
    
    # 4. Update config.csv (Field 7: name, Field 11: branch)
    local tmp_config=$(mktemp)
    awk -v old="$old_name" -v new="$new_name" -F'|' 'BEGIN{OFS="|"} { 
        if ($7 == old) { 
            $7 = new; 
            if ($11 == old) $11 = new 
        } 
        print 
    }' "$CONFIG_FILE" > "$tmp_config" && mv "$tmp_config" "$CONFIG_FILE"
    
    success "Setup renamed from '$old_name' to '$new_name' in configuration."
    
    # 5. Rename branch in bare repo if it matches old name
    if [[ -d "$repo_path" ]]; then
        if git --git-dir="$repo_path" rev-parse --verify "$old_name" &>/dev/null; then
            info "Renaming branch '$old_name' to '$new_name' in repository..."
            git --git-dir="$repo_path" branch -m "$old_name" "$new_name"
            success "Branch renamed successfully."
        fi
    fi
}

# Main command dispatcher
main() {
    # Global option parsing
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --setup|--branch)
                SELECTED_SETUP="$2"
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done

    if [[ $# -eq 0 ]]; then
        cmd_help
        exit 0
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        init)             cmd_init "$@" ;;
        clone)            cmd_clone "$@" ;;
        list)             cmd_list "$@" ;;
        rm)               cmd_rm "$@" ;;
        rename)           cmd_rename "$@" ;;
        setup:show)       cmd_setup_show "$@" ;;
        bash:list)        cmd_bash_list "$@" ;;
        bash:init)        cmd_bash_init "$@" ;;
        bash:reload)      cmd_bash_reload "$@" ;;
        add-remote)       cmd_add_remote "$@" ;;
        list-remotes)     cmd_list_remotes "$@" ;;
        remove-remote)    cmd_remove_remote "$@" ;;
        registry:list)    cmd_registry_list "$@" ;;
        registry:use)     cmd_registry_use "$@" ;;
        branch-ensure)    cmd_branch_ensure "$@" ;;
        ensure-remote-branch) cmd_ensure_remote_branch "$@" ;;
        merge)            cmd_merge "$@" ;;
        sync)             cmd_sync "$@" ;;
        status)           cmd_status "$@" ;;
        add)              cmd_add "$@" ;;
        commit)           cmd_commit "$@" ;;
        push)             cmd_push "$@" ;;
        pull)             cmd_pull "$@" ;;
        diff)             cmd_diff "$@" ;;
        help|--help|-h)   cmd_help ;;
        *)
            error "Unknown command: $command"
            echo ""
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
