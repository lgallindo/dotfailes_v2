#!/usr/bin/env bash
# Installation script for dotfailes
# This script helps you get started with dotfailes quickly

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

detected_os="$(uname -s)"
detected_hostname="$(hostname)"
echo detected_os: "$detected_os"
echo detected_hostname: "$detected_hostname"
echo TERM_PROGRAM: "$TERM_PROGRAM"

# Detect user - cross-platform safe approach
if [[ -z "$USER" ]]; then
    if command -v whoami &> /dev/null; then
        USER="$(whoami)"
    elif [[ -n "$USERNAME" ]]; then
        USER="$USERNAME"
    else
        USER="unknown"
    fi
fi

# Global variables for row counting
CONFIG_ROW_COUNT=0
ROLLBACK_ROW_COUNT=0
CALL_ARGS="$@"
SCRIPT_NAME="$(basename "$0")"
SCRIPT_VERSION="1.0.0"

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

die() {
    error "$1"
    exit 1
}

# Detect OS
detect_os() {
    case "$detected_os" in
        Linux*)     echo "Linux";;
        Darwin*)    echo "MacOS";;
        CYGWIN*)    echo "Windows";;
        MINGW*)     echo "Windows";;
        MSYS*)      echo "Windows";;
        *)          echo "Unknown";;
    esac
}

# Check if jq is installed
check_jq() {
    if ! command -v jq &> /dev/null; then
        error "jq is not installed"
        echo ""
        echo "Please install jq to use dotfailes:"
        echo ""
        case "$(detect_os)" in
            Linux)
                echo "  Debian/Ubuntu: sudo apt-get install jq"
                echo "  Fedora:        sudo dnf install jq"
                echo "  Arch:          sudo pacman -S jq"
                ;;
            MacOS)
                echo "  Homebrew:      brew install jq"
                echo "  MacPorts:      sudo port install jq"
                ;;
            Windows)
                echo "  Git Bash:      Download from https://stedolan.github.io/jq/"
                echo "  MSYS2:         pacman -S jq"
                ;;
        esac
        echo ""
        exit 1
    fi
}

# Check if git is installed
check_git() {
    if ! command -v git &> /dev/null; then
        die "git is not installed or not in the PATH. Please install git first and make sure it is in the PATH."
    fi
}

# Append config entry (key-value pair with metadata)
append_config() {
    local key="$1"
    local value="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    # Escape pipe characters in values
    value="${value//\|/\\|}"
    
    # Append to config log
    mkdir -p "./logs"
    
    # Add header if file doesn't exist or is empty
    if [[ ! -s "./logs/config.log" ]]; then
        printf '# TIMESTAMP|SCRIPT|USER|PWD|CALL_ARGS|VERSION|KEY|VALUE\n' > "./logs/config.log"
    fi
    
    printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$timestamp" "$SCRIPT_NAME" "$USER" "$PWD" "$CALL_ARGS" "$SCRIPT_VERSION" "$key" "$value" >> "./logs/config.log"
    
    CONFIG_ROW_COUNT=$((CONFIG_ROW_COUNT + 1))
    info "[${timestamp}] Logged: $key=$value"
}

# Append rollback instruction (action with revert command)
append_rollback() {
    local action="$1"
    local description="$2"
    local revert_cmd="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    
    # Escape pipe characters
    description="${description//\|/\\|}"
    revert_cmd="${revert_cmd//\|/\\|}"
    
    # Append to rollback log
    mkdir -p "./logs"
    
    # Add header if file doesn't exist or is empty
    if [[ ! -s "./logs/rollback.log" ]]; then
        printf '# TIMESTAMP|SCRIPT|USER|PWD|CALL_ARGS|VERSION|ACTION|DESCRIPTION|REVERT_CMD\n' > "./logs/rollback.log"
    fi
    
    printf '%s|%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$timestamp" "$SCRIPT_NAME" "$USER" "$PWD" "$CALL_ARGS" "$SCRIPT_VERSION" "$action" "$description" "$revert_cmd" >> "./logs/rollback.log"
    
    ROLLBACK_ROW_COUNT=$((ROLLBACK_ROW_COUNT + 1))
    info "[${timestamp}] Action logged: $action"
}

# Update log file headers with row count
update_log_headers() {
    # Cleanup function - no row count logging
    return
}

# Register cleanup on exit
trap update_log_headers EXIT

# Rollback function - undoes installation
rollback() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
    info "[${timestamp}] Starting rollback process"
    
    # Check if CSV config exists
    if [[ ! -f "$CSV_CONFIG_FILE" ]]; then
        warn "[${timestamp}] No install_config.csv found. Nothing to rollback."
        return
    fi
    
    # Read the last entry from CSV (skip header)
    local csv_entry=$(tail -n 1 "$CSV_CONFIG_FILE")
    if [[ -z "$csv_entry" ]]; then
        warn "[${timestamp}] CSV file is empty. Nothing to rollback."
        return
    fi
    
    # Parse CSV fields (order: ALIAS_CMD,ROLLBACK_LOG,SCRIPT,SHELL_CONFIG,DEFAULT_REPO_PATH,DEFAULT_SETUP_NAME,DEFAULT_FOLDER)
    IFS=',' read -r ALIAS_CMD ROLLBACK_LOG SCRIPT SHELL_CONFIG DEFAULT_REPO_PATH DEFAULT_SETUP_NAME DEFAULT_FOLDER <<< "$csv_entry"
    
    info "[${timestamp}] Parsed rollback data from CSV"
    info "[${timestamp}] - Alias target: $SHELL_CONFIG"
    info "[${timestamp}] - Repo path: $DEFAULT_REPO_PATH"
    
    # Remove alias from shell config if it exists
    if [[ -n "$SHELL_CONFIG" && -f "$SHELL_CONFIG" ]]; then
        if grep -q "alias dotfiles=" "$SHELL_CONFIG"; then
            # Create backup of shell config
            cp "$SHELL_CONFIG" "${SHELL_CONFIG}.pre-rollback"
            info "[${timestamp}] Created backup: ${SHELL_CONFIG}.pre-rollback"
            
            # Remove dotfiles alias lines
            grep -v "dotfiles" "$SHELL_CONFIG" > "${SHELL_CONFIG}.tmp" && mv "${SHELL_CONFIG}.tmp" "$SHELL_CONFIG"
            success "[${timestamp}] Removed dotfiles alias from $SHELL_CONFIG"
            log_rollback_instruction "alias_removed" "$SHELL_CONFIG"
        fi
    fi
    
    # Remove repository directory if specified
    if [[ -n "$DEFAULT_REPO_PATH" && -d "$DEFAULT_REPO_PATH" ]]; then
        read -p "Remove dotfiles repository at $DEFAULT_REPO_PATH? (y/n) " -r remove_repo
        if [[ "$remove_repo" =~ ^[Yy]$ ]]; then
            rm -rf "$DEFAULT_REPO_PATH"
            success "[${timestamp}] Removed repository: $DEFAULT_REPO_PATH"
            log_rollback_instruction "repo_removed" "$DEFAULT_REPO_PATH"
        fi
    fi
    
    # Optionally remove CSV config
    read -p "Remove install_config.csv? (y/n) " -r remove_csv
    if [[ "$remove_csv" =~ ^[Yy]$ ]]; then
        rm -f "$CSV_CONFIG_FILE"
        success "[${timestamp}] Removed CSV config: $CSV_CONFIG_FILE"
        log_rollback_instruction "csv_removed" "$CSV_CONFIG_FILE"
    fi
    
    success "[${timestamp}] Rollback complete!"
}

# Detect shell and set appropriate script
detect_shell() {
    local shell_choice="${SHELL_CHOICE:-auto}"
    
    case "$shell_choice" in
        bash)
            DETECTED_SHELL="bash"
            SCRIPT="dotfailes.sh"
            SHELL_CONFIG="$HOME/.bashrc"
            ;;
        zsh)
            DETECTED_SHELL="zsh"
            SCRIPT="dotfailes.zsh"
            SHELL_CONFIG="$HOME/.zshrc"
            ;;
        ksh)
            DETECTED_SHELL="ksh"
            SCRIPT="dotfailes.sh"
            SHELL_CONFIG="$HOME/.kshrc"
            ;;
        ksh93)
            DETECTED_SHELL="ksh93"
            SCRIPT="dotfailes.sh"
            SHELL_CONFIG="$HOME/.kshrc"
            ;;
        dash)
            DETECTED_SHELL="dash"
            SCRIPT="dotfailes.sh"
            SHELL_CONFIG="$HOME/.dashrc"
            ;;
        fish)
            DETECTED_SHELL="fish"
            SCRIPT="dotfailes.fish"
            SHELL_CONFIG="$HOME/.config/fish/config.fish"
            ;;
        auto)
            local current_shell=$(basename "$SHELL")
            case "$current_shell" in
                zsh)
                    DETECTED_SHELL="zsh"
                    SCRIPT="dotfailes.zsh"
                    SHELL_CONFIG="$HOME/.zshrc"
                    ;;
                fish)
                    DETECTED_SHELL="fish"
                    SCRIPT="dotfailes.fish"
                    SHELL_CONFIG="$HOME/.config/fish/config.fish"
                    ;;
                ksh|ksh93)
                    DETECTED_SHELL="$current_shell"
                    SCRIPT="dotfailes.sh"
                    SHELL_CONFIG="$HOME/.kshrc"
                    ;;
                dash)
                    DETECTED_SHELL="dash"
                    SCRIPT="dotfailes.sh"
                    SHELL_CONFIG="$HOME/.dashrc"
                    ;;
                bash|*)
                    DETECTED_SHELL="bash"
                    SCRIPT="dotfailes.sh"
                    SHELL_CONFIG="$HOME/.bashrc"
                    ;;
            esac
            ;;
        *)
            error "Unknown shell: $shell_choice"
            exit 1
            ;;
    esac
    
    # Log detected shell after assignment
    append_config "OS" "$(detect_os)"
    append_config "SHELL" "$DETECTED_SHELL"
    append_config "SCRIPT" "$SCRIPT"
    append_config "SHELL_CONFIG" "$SHELL_CONFIG"
    info "Detected: $DETECTED_SHELL shell -> $SCRIPT"
}

# Main installation
main() {
    # Log environment information
    append_config "CALL" "$CALL_ARGS"
    append_config "DETECTED_OS_RAW" "$detected_os"
    append_config "HOSTNAME" "$detected_hostname"
    append_config "TERM_PROGRAM" "$TERM_PROGRAM"
    append_config "WHOAMI" "$(whoami 2>/dev/null || echo '')"
    append_config "USER" "$USER"
    append_config "USERNAME" "$USERNAME"
    
    # Parse CLI arguments for non-interactive mode
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --repo-path)
                REPO_PATH="$2"; shift 2;;
            --setup-name)
                SETUP_NAME="$2"; shift 2;;
            --dotfiles-folder)
                DOTFILES_FOLDER="$2"; shift 2;;
            --no-alias)
                NO_ALIAS=1; shift;;
            --remote)
                REPO_URL="$2"; shift 2;;
            --shell)
                SHELL_CHOICE="$2"; shift 2;;
            --rollback)
                ROLLBACK_MODE=1; shift;;
            --help)
                echo "Usage: $0 [--repo-path PATH] [--setup-name NAME] [--dotfiles-folder DIR] [--no-alias] [--remote URL] [--shell SHELL] [--rollback]"; exit 0;;
            *)
                break;;
        esac
    done
    # Old CSV functions no longer used - using new pipe-delimited format
    
    # Check prerequisites
    check_jq
    check_git
    
    # Handle rollback mode if requested
    if [[ "$ROLLBACK_MODE" == 1 ]]; then
        rollback
        return
    fi
    
    # Detect shell and set script/config
    detect_shell
    
    if [[ -n "$REPO_PATH" && -n "$SETUP_NAME" && -n "$DOTFILES_FOLDER" ]]; then
            # Non-interactive mode
            info "Repository path: $REPO_PATH"
            info "Config file: $HOME/.dotfailes/config.json"
            info "Initializing repository (non-interactive mode)..."
            ./$SCRIPT init "$REPO_PATH" "$SETUP_NAME" "$DOTFILES_FOLDER"
            # Alias
            if [[ -z "$NO_ALIAS" ]]; then
                ALIAS_COMMENT="# dotfailes alias (repo: ${REPO_URL:-https://github.com/lgallindo/dotfailes_v2})"
                ALIAS_CMD="alias dotfiles='git --git-dir=$REPO_PATH --work-tree=$DOTFILES_FOLDER'"
                BASH_ALIASES="$HOME/.bash_aliases"
                if [[ -f "$BASH_ALIASES" && -f "$HOME/.bashrc" && $(grep -E "^ *(source|\. +) *~?/.bash_aliases" "$HOME/.bashrc") ]]; then
                    ALIAS_TARGET="$BASH_ALIASES"
                else
                    ALIAS_TARGET="$SHELL_CONFIG"
                fi
                if ! grep -q "alias dotfiles=" "$ALIAS_TARGET" 2>/dev/null; then
                    echo "" >> "$ALIAS_TARGET"
                    echo "$ALIAS_COMMENT" >> "$ALIAS_TARGET"
                    echo "$ALIAS_CMD" >> "$ALIAS_TARGET"
                    success "Added dotfiles alias to $ALIAS_TARGET"
                    append_config "ALIAS_TARGET" "$ALIAS_TARGET"
                    append_rollback "alias_added" "Added dotfiles alias to $ALIAS_TARGET" "grep -v 'dotfiles' '$ALIAS_TARGET' > '${ALIAS_TARGET}.tmp' && mv '${ALIAS_TARGET}.tmp' '$ALIAS_TARGET'"
                    info "Run 'source $ALIAS_TARGET' to load the alias in your current shell"
                fi
            fi
            append_config "REPO_PATH" "$REPO_PATH"
            append_config "SETUP_NAME" "$SETUP_NAME"
            append_config "DOTFILES_FOLDER" "$DOTFILES_FOLDER"
            if [[ -n "$REPO_URL" ]]; then
                append_config "REPO_URL" "$REPO_URL"
            fi
            if [[ -n "$REPO_URL" ]]; then
                info "Adding remote origin: $REPO_URL"
                $([[ -n "$GIT_EXECUTABLE" ]] && echo "$GIT_EXECUTABLE" || echo git) --git-dir="$REPO_PATH" --work-tree="$DOTFILES_FOLDER" remote add origin "$REPO_URL" 2>/dev/null || true
                $([[ -n "$GIT_EXECUTABLE" ]] && echo "$GIT_EXECUTABLE" || echo git) --git-dir="$REPO_PATH" --work-tree="$DOTFILES_FOLDER" push --set-upstream origin main 2>/dev/null || true
            fi
            success "Setup complete! (non-interactive)"
            return
        fi

        # Interactive mode (default)
        echo "Would you like to initialize your dotfiles repository now? (y/n)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo ""
            info "Let's set up your dotfiles repository"
            echo ""
            # Get repository path
            DEFAULT_REPO_PATH="$HOME/.dotfiles"
            echo "Where would you like to store your dotfiles repository?"
            echo "  (default: $DEFAULT_REPO_PATH)"
            read -r REPO_PATH
            REPO_PATH=${REPO_PATH:-$DEFAULT_REPO_PATH}
            info "Repository path: $REPO_PATH"
            # Get setup name
            local OS=$(detect_os)
            DEFAULT_SETUP_NAME="$(hostname)-$OS"
            echo ""
            echo "What would you like to name this setup?"
            echo "  (default: $DEFAULT_SETUP_NAME)"
            read -r SETUP_NAME
            SETUP_NAME=${SETUP_NAME:-$DEFAULT_SETUP_NAME}
            # Get dotfiles folder
            DEFAULT_FOLDER="$HOME"
            echo ""
            echo "Which directory contains your dotfiles?"
            echo "  (default: $DEFAULT_FOLDER)"
            read -r DOTFILES_FOLDER
            DOTFILES_FOLDER=${DOTFILES_FOLDER:-$DEFAULT_FOLDER}
            # Initialize repository
            echo ""
            info "Initializing repository..."
            ./$SCRIPT init "$REPO_PATH" "$SETUP_NAME" "$DOTFILES_FOLDER"
            echo ""
            # Log config file location
            CONFIG_FILE="$HOME/.dotfailes/config.json"
            info "Config file: $CONFIG_FILE"
            # Ask about adding alias
            echo "Would you like to add the dotfiles alias to $SHELL_CONFIG? (y/n)"
            read -r add_alias
            if [[ "$add_alias" =~ ^[Yy]$ ]]; then
                if [[ -z "$REPO_URL" ]]; then
                    echo "Enter the URL for your dotfiles repo (for comment, optional):"
                    read -r REPO_URL
                fi
                ALIAS_COMMENT="# dotfailes alias (repo: ${REPO_URL:-https://github.com/lgallindo/dotfailes_v2})"
                ALIAS_CMD="alias dotfiles='git --git-dir=$REPO_PATH --work-tree=$DOTFILES_FOLDER'"
                BASH_ALIASES="$HOME/.bash_aliases"
                if [[ -f "$BASH_ALIASES" && -f "$HOME/.bashrc" && $(grep -E "^ *(source|\. +) *~?/.bash_aliases" "$HOME/.bashrc") ]]; then
                    ALIAS_TARGET="$BASH_ALIASES"
                else
                    ALIAS_TARGET="$SHELL_CONFIG"
                fi
                if ! grep -q "alias dotfiles=" "$ALIAS_TARGET" 2>/dev/null; then
                    echo "" >> "$ALIAS_TARGET"
                    echo "$ALIAS_COMMENT" >> "$ALIAS_TARGET"
                    echo "$ALIAS_CMD" >> "$ALIAS_TARGET"
                    success "Added dotfiles alias to $ALIAS_TARGET"
                    append_config "ALIAS_TARGET" "$ALIAS_TARGET"
                    append_rollback "alias_added" "Added dotfiles alias to $ALIAS_TARGET" "grep -v 'dotfiles' '$ALIAS_TARGET' > '${ALIAS_TARGET}.tmp' && mv '${ALIAS_TARGET}.tmp' '$ALIAS_TARGET'"
                    info "Run 'source $ALIAS_TARGET' to load the alias in your current shell"
                fi
            fi
            append_config "REPO_PATH" "$REPO_PATH"
            append_config "SETUP_NAME" "$SETUP_NAME"
            append_config "DOTFILES_FOLDER" "$DOTFILES_FOLDER"
            if [[ -n "$REPO_URL" ]]; then
                append_config "REPO_URL" "$REPO_URL"
            fi
            if [[ -n "$REPO_URL" ]]; then
                info "Adding remote origin: $REPO_URL"
                $([[ -n "$GIT_EXECUTABLE" ]] && echo "$GIT_EXECUTABLE" || echo git) --git-dir="$REPO_PATH" --work-tree="$DOTFILES_FOLDER" remote add origin "$REPO_URL" 2>/dev/null || true
                $([[ -n "$GIT_EXECUTABLE" ]] && echo "$GIT_EXECUTABLE" || echo git) --git-dir="$REPO_PATH" --work-tree="$DOTFILES_FOLDER" push --set-upstream origin main 2>/dev/null || true
            fi
            echo ""
            success "Setup complete!"
            echo ""
            echo "Next steps:"
            echo "  1. Source your shell config: source $SHELL_CONFIG"
            echo "  2. Hide untracked files: dotfiles config --local status.showUntrackedFiles no"
            echo "  3. Add your first dotfiles: dotfiles add ~/.bashrc"
            echo "  4. Commit: dotfiles commit -m 'Initial commit'"
            echo "  5. (Optional) Add remote: dotfiles remote add origin <url>"
            echo ""
        else
            echo ""
            info "You can manually initialize your repository later with:"
            echo "  ./$SCRIPT init <repo_path> <setup_name> <dotfiles_folder>"
            echo ""
            info "Or run this installation script again."
            echo ""
        fi
    
    # Make script executable
    chmod +x "$SCRIPT"
    info "Made $SCRIPT executable"
    echo ""
    
    info "For more information, see README.md and EXAMPLES.md"
}

main "$@"
