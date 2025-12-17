#!/usr/bin/env zsh
# dotfailes - Dotfile management using bare git repositories
# Copyright (C) 2025
# Licensed under GNU General Public License v3.0

setopt errexit

# Default configuration
DEFAULT_DOTFILES_DIR="${HOME}/.dotfailes"
DOTFILES_DIR="${DOTFILES_DIR:-$DEFAULT_DOTFILES_DIR}"
CONFIG_FILE="${DOTFILES_DIR}/config.json"

# Colors for output
autoload -U colors && colors

# Helper functions
info() {
    print -P "%F{blue}[INFO]%f $1"
}

success() {
    print -P "%F{green}[SUCCESS]%f $1"
}

warn() {
    print -P "%F{yellow}[WARN]%f $1"
}

error() {
    print -P "%F{red}[ERROR]%f $1" >&2
}

die() {
    error "$1"
    exit 1
}

# Initialize configuration file if it doesn't exist
init_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        mkdir -p "$(dirname "$CONFIG_FILE")"
        cat > "$CONFIG_FILE" <<EOF
{
  "setups": []
}
EOF
        success "Configuration file created at $CONFIG_FILE"
    fi
}

# Get OS type
get_os() {
    case "$(uname -s)" in
        Linux*)     echo "Linux";;
        Darwin*)    echo "MacOS";;
        CYGWIN*)    echo "Windows";;
        MINGW*)     echo "Windows";;
        MSYS*)      echo "Windows";;
        *)          echo "Unknown";;
    esac
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
        print -n "Do you want to continue? (y/n) "
        read -r reply
        if [[ ! "$reply" =~ ^[Yy]$ ]]; then
            die "Initialization cancelled"
        fi
    fi
    
    mkdir -p "$repo_path"
    git init --bare "$repo_path"
    success "Bare git repository initialized at $repo_path"
    
    # Add to configuration
    init_config
    local os_type=$(get_os)
    
    # Update config with new setup
    local temp_file=$(mktemp)
    jq --arg name "$setup_name" \
       --arg os "$os_type" \
       --arg folder "$dotfiles_folder" \
       --arg repo "$repo_path" \
       '.setups += [{name: $name, os: $os, folder: $folder, repo: $repo}]' \
       "$CONFIG_FILE" > "$temp_file" && mv "$temp_file" "$CONFIG_FILE"
    
    success "Setup '$setup_name' registered (OS: $os_type, Folder: $dotfiles_folder)"
    
    # Create alias helper
    info "To use this dotfile repository, add this alias to your .zshrc:"
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
    git clone --bare "$remote_url" "$repo_path"
    success "Repository cloned to $repo_path"
    
    # Add to configuration
    init_config
    local os_type=$(get_os)
    
    local temp_file=$(mktemp)
    jq --arg name "$setup_name" \
       --arg os "$os_type" \
       --arg folder "$dotfiles_folder" \
       --arg repo "$repo_path" \
       '.setups += [{name: $name, os: $os, folder: $folder, repo: $repo}]' \
       "$CONFIG_FILE" > "$temp_file" && mv "$temp_file" "$CONFIG_FILE"
    
    success "Setup '$setup_name' registered"
    
    # Create alias helper
    info "To use this dotfile repository, add this alias to your .zshrc:"
    echo ""
    echo "    alias dotfiles='git --git-dir=$repo_path --work-tree=$dotfiles_folder'"
    echo ""
}

# List all configured setups
cmd_list() {
    init_config
    
    local count=$(jq '.setups | length' "$CONFIG_FILE")
    
    if [[ "$count" -eq 0 ]]; then
        warn "No setups configured yet"
        return
    fi
    
    info "Configured setups:"
    echo ""
    jq -r '.setups[] | "  • \(.name)\n    OS: \(.os)\n    Folder: \(.folder)\n    Repo: \(.repo)\n"' "$CONFIG_FILE"
}

# Add remote to a setup
cmd_add_remote() {
    local setup_name="$1"
    local remote_name="$2"
    local remote_url="$3"
    
    if [[ -z "$setup_name" ]] || [[ -z "$remote_name" ]] || [[ -z "$remote_url" ]]; then
        die "Usage: $0 add-remote <setup_name> <remote_name> <remote_url>"
    fi
    
    init_config
    
    # Get repository path for setup
    local repo_path=$(jq -r --arg name "$setup_name" '.setups[] | select(.name == $name) | .repo' "$CONFIG_FILE")
    
    if [[ -z "$repo_path" ]] || [[ "$repo_path" == "null" ]]; then
        die "Setup '$setup_name' not found"
    fi
    
    # Add remote
    git --git-dir="$repo_path" remote add "$remote_name" "$remote_url" 2>/dev/null || \
        git --git-dir="$repo_path" remote set-url "$remote_name" "$remote_url"
    
    success "Remote '$remote_name' added to setup '$setup_name'"
}

# List remotes for a setup
cmd_list_remotes() {
    local setup_name="$1"
    
    if [[ -z "$setup_name" ]]; then
        die "Usage: $0 list-remotes <setup_name>"
    fi
    
    init_config
    
    local repo_path=$(jq -r --arg name "$setup_name" '.setups[] | select(.name == $name) | .repo' "$CONFIG_FILE")
    
    if [[ -z "$repo_path" ]] || [[ "$repo_path" == "null" ]]; then
        die "Setup '$setup_name' not found"
    fi
    
    info "Remotes for setup '$setup_name':"
    git --git-dir="$repo_path" remote -v
}

# Remove remote from a setup
cmd_remove_remote() {
    local setup_name="$1"
    local remote_name="$2"
    
    if [[ -z "$setup_name" ]] || [[ -z "$remote_name" ]]; then
        die "Usage: $0 remove-remote <setup_name> <remote_name>"
    fi
    
    init_config
    
    local repo_path=$(jq -r --arg name "$setup_name" '.setups[] | select(.name == $name) | .repo' "$CONFIG_FILE")
    
    if [[ -z "$repo_path" ]] || [[ "$repo_path" == "null" ]]; then
        die "Setup '$setup_name' not found"
    fi
    
    git --git-dir="$repo_path" remote remove "$remote_name"
    success "Remote '$remote_name' removed from setup '$setup_name'"
}

# Sync with remote (push and pull)
cmd_sync() {
    local setup_name="$1"
    local remote_name="${2:-origin}"
    local branch="${3:-main}"
    
    if [[ -z "$setup_name" ]]; then
        die "Usage: $0 sync <setup_name> [remote_name] [branch]"
    fi
    
    init_config
    
    local repo_path=$(jq -r --arg name "$setup_name" '.setups[] | select(.name == $name) | .repo' "$CONFIG_FILE")
    local work_tree=$(jq -r --arg name "$setup_name" '.setups[] | select(.name == $name) | .folder' "$CONFIG_FILE")
    
    if [[ -z "$repo_path" ]] || [[ "$repo_path" == "null" ]]; then
        die "Setup '$setup_name' not found"
    fi
    
    info "Syncing setup '$setup_name' with remote '$remote_name'..."
    
    # Pull changes
    info "Pulling changes from $remote_name/$branch..."
    git --git-dir="$repo_path" --work-tree="$work_tree" pull "$remote_name" "$branch" || warn "Pull failed or no changes"
    
    # Push changes
    info "Pushing changes to $remote_name/$branch..."
    git --git-dir="$repo_path" --work-tree="$work_tree" push "$remote_name" "$branch" || warn "Push failed or no changes"
    
    success "Sync completed"
}

# Show status for a setup
cmd_status() {
    local setup_name="$1"
    
    if [[ -z "$setup_name" ]]; then
        die "Usage: $0 status <setup_name>"
    fi
    
    init_config
    
    local repo_path=$(jq -r --arg name "$setup_name" '.setups[] | select(.name == $name) | .repo' "$CONFIG_FILE")
    local work_tree=$(jq -r --arg name "$setup_name" '.setups[] | select(.name == $name) | .folder' "$CONFIG_FILE")
    
    if [[ -z "$repo_path" ]] || [[ "$repo_path" == "null" ]]; then
        die "Setup '$setup_name' not found"
    fi
    
    info "Status for setup '$setup_name':"
    git --git-dir="$repo_path" --work-tree="$work_tree" status
}

# Show help
cmd_help() {
    cat <<EOF
dotfailes - Dotfile management using bare git repositories

USAGE:
    $0 <command> [arguments]

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
    $0 init ~/.dotfiles my-macbook ~/
    
    # Clone existing dotfile repository
    $0 clone https://github.com/user/dotfiles.git ~/.dotfiles
    
    # Add a remote
    $0 add-remote my-macbook origin https://github.com/user/dotfiles.git
    
    # Sync with remote
    $0 sync my-macbook origin main
    
    # Check status
    $0 status my-macbook

CONFIGURATION:
    Configuration is stored in: $CONFIG_FILE
    
    Each setup tracks:
    - Setup name
    - Operating system
    - Dotfiles folder (work tree)
    - Repository path (bare git repo)

ZSH SPECIFIC:
    Common zsh dotfiles to manage:
    - ~/.zshrc        : Main zsh configuration
    - ~/.zshenv       : Environment variables
    - ~/.zprofile     : Login shell configuration
    - ~/.zlogin       : Login commands
    - ~/.zlogout      : Logout commands

EOF
}

# Main command dispatcher
main() {
    if [[ $# -eq 0 ]]; then
        cmd_help
        exit 0
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        init)
            cmd_init "$@"
            ;;
        clone)
            cmd_clone "$@"
            ;;
        list)
            cmd_list "$@"
            ;;
        add-remote)
            cmd_add_remote "$@"
            ;;
        list-remotes)
            cmd_list_remotes "$@"
            ;;
        remove-remote)
            cmd_remove_remote "$@"
            ;;
        sync)
            cmd_sync "$@"
            ;;
        status)
            cmd_status "$@"
            ;;
        help|--help|-h)
            cmd_help
            ;;
        *)
            error "Unknown command: $command"
            echo ""
            cmd_help
            exit 1
            ;;
    esac
}

main "$@"
