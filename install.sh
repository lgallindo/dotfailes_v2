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

# Main installation
main() {
    # CSV config file in current directory
    CSV_CONFIG_FILE="./install_config.csv"
    # CSV header
    CSV_HEADER="ALIAS_CMD,ROLLBACK_LOG,SCRIPT,SHELL_CONFIG,DEFAULT_REPO_PATH,DEFAULT_SETUP_NAME,DEFAULT_FOLDER"

    # Function to write config to CSV
    write_csv_config() {
        echo "$CSV_HEADER" > "$CSV_CONFIG_FILE"
        echo "$ALIAS_CMD,$ROLLBACK_LOG,$SCRIPT,$SHELL_CONFIG,$DEFAULT_REPO_PATH,$DEFAULT_SETUP_NAME,$DEFAULT_FOLDER" >> "$CSV_CONFIG_FILE"
    }

    # Function to load config from CSV if present
    load_csv_config() {
        if [[ -f "$CSV_CONFIG_FILE" ]]; then
            IFS=',' read -r _ALIAS_CMD _ROLLBACK_LOG _SCRIPT _SHELL_CONFIG _DEFAULT_REPO_PATH _DEFAULT_SETUP_NAME _DEFAULT_FOLDER < <(tail -n +2 "$CSV_CONFIG_FILE")
            # Only set if not empty
            [[ -n "$_ALIAS_CMD" ]] && ALIAS_CMD="$_ALIAS_CMD"
            [[ -n "$_ROLLBACK_LOG" ]] && ROLLBACK_LOG="$_ROLLBACK_LOG"
            [[ -n "$_SCRIPT" ]] && SCRIPT="$_SCRIPT"
            [[ -n "$_SHELL_CONFIG" ]] && SHELL_CONFIG="$_SHELL_CONFIG"
            [[ -n "$_DEFAULT_REPO_PATH" ]] && DEFAULT_REPO_PATH="$_DEFAULT_REPO_PATH"
            [[ -n "$_DEFAULT_SETUP_NAME" ]] && DEFAULT_SETUP_NAME="$_DEFAULT_SETUP_NAME"
            [[ -n "$_DEFAULT_FOLDER" ]] && DEFAULT_FOLDER="$_DEFAULT_FOLDER"
            info "Loaded configuration from $CSV_CONFIG_FILE"
        fi
    }

    # Set defaults
    ROLLBACK_LOG="$HOME/.dotfailes/dotfailes_rollback.log"
    SCRIPT=""
    SHELL_CONFIG=""
    DEFAULT_REPO_PATH="$HOME/.dotfiles"
    DEFAULT_SETUP_NAME="$(hostname)-$(detect_os)"
    DEFAULT_FOLDER="$HOME"
    ALIAS_CMD=""

    # Load from CSV if present
    load_csv_config

    # Log an action for rollback
    log_action() {
        echo "$1" >> "$ROLLBACK_LOG"
    }

    # Rollback changes made by install.sh
    rollback() {
        if [[ ! -f "$ROLLBACK_LOG" ]]; then
            error "No rollback log found. Nothing to undo."
            exit 1
        fi
        info "Rolling back changes..."
        while IFS= read -r line; do
            case "$line" in
                "ALIAS:"*)
                    shell_file="${line#ALIAS:}"
                    if [[ -f "$shell_file" ]]; then
                        sed -i.bak '/# dotfailes alias/d;/alias dotfiles=.*# dotfailes alias/d' "$shell_file"
                        success "Removed dotfiles alias from $shell_file"
                    fi
                    ;;
                "REPO:"*)
                    repo_dir="${line#REPO:}"
                    if [[ -d "$repo_dir" ]]; then
                        rm -rf "$repo_dir"
                        success "Removed repo directory $repo_dir"
                    fi
                    ;;
                "CONFIG:"*)
                    config_file="${line#CONFIG:}"
                    if [[ -f "$config_file" ]]; then
                        rm -f "$config_file"
                        success "Removed config file $config_file"
                    fi
                    ;;
            esac
        done < "$ROLLBACK_LOG"
        rm -f "$ROLLBACK_LOG"
        success "Rollback complete."
        exit 0
    }

    echo "=================================="
    echo "   dotfailes Installation Script   "
    echo "=================================="
    echo ""
    
    # Check prerequisites
    info "Checking prerequisites..."
    check_git
    check_jq
    success "All prerequisites installed"
    echo ""
    

    # Detect OS
    OS=$(detect_os)
    info "Detected OS: $OS"
    echo ""

    # Only set SCRIPT/SHELL_CONFIG if not loaded from CSV
    if [[ -z "$SCRIPT" || -z "$SHELL_CONFIG" ]]; then
        case "$OS" in
            Linux)
                SCRIPT="dotfailes.sh"
                SHELL_CONFIG="$HOME/.bashrc"
                ;;
            MacOS)
                SCRIPT="dotfailes.zsh"
                SHELL_CONFIG="$HOME/.zshrc"
                ;;
            *)
                SCRIPT="dotfailes.sh"
                SHELL_CONFIG="$HOME/.bashrc"
                warn "Using bash script as default"
                ;;
        esac
    fi

    # Make script executable
    chmod +x "$SCRIPT"
    info "Made $SCRIPT executable"
    echo ""
    
    if [[ "$1" == "rollback" ]]; then
        rollback
    fi
    
    # Ask user if they want to set up now
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
        log_action "REPO:$REPO_PATH"
        
        # Get setup name
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
        ./"$SCRIPT" init "$REPO_PATH" "$SETUP_NAME" "$DOTFILES_FOLDER"
        echo ""
        
        # Ask about adding alias
        echo "Would you like to add the dotfiles alias to $SHELL_CONFIG? (y/n)"
        read -r add_alias
        
        if [[ "$add_alias" =~ ^[Yy]$ ]]; then
            # Prompt for repo URL for comment (or use from config if available)
            if [[ -z "$REPO_URL" ]]; then
                echo "Enter the URL for your dotfiles repo (for comment, optional):"
                read -r REPO_URL
            fi
            # Compose identifying comment with repo URL
            ALIAS_COMMENT="# dotfailes alias (repo: ${REPO_URL:-https://github.com/lgallindo/dotfailes_v2})"
            ALIAS_CMD="alias dotfiles='git --git-dir=$REPO_PATH --work-tree=$DOTFILES_FOLDER'"

            # Check for .bash_aliases usage
            BASH_ALIASES="$HOME/.bash_aliases"
            if [[ -f "$BASH_ALIASES" && -f "$HOME/.bashrc" && $(grep -E "^ *(source|\. +) *~?/.bash_aliases" "$HOME/.bashrc") ]]; then
                ALIAS_TARGET="$BASH_ALIASES"
            else
                ALIAS_TARGET="$SHELL_CONFIG"
            fi

            # Check if alias already exists
            if grep -q "alias dotfiles=" "$ALIAS_TARGET" 2>/dev/null; then
                warn "Dotfiles alias already exists in $ALIAS_TARGET"
            else
                echo "" >> "$ALIAS_TARGET"
                echo "$ALIAS_COMMENT" >> "$ALIAS_TARGET"
                echo "$ALIAS_CMD" >> "$ALIAS_TARGET"
                success "Added dotfiles alias to $ALIAS_TARGET"
                echo ""
                info "Run 'source $ALIAS_TARGET' to load the alias in your current shell"
            fi
        fi
        
        # Write config to CSV
        write_csv_config

        # If a remote URL is known, add it and set upstream
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
    
    info "For more information, see README.md and EXAMPLES.md"
}

main
