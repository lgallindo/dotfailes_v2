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
    case "$(uname -s)" in
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
        die "git is not installed. Please install git first."
    fi
}

# Main installation
main() {
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
    
    # Determine which script to use
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
    
    # Make script executable
    chmod +x "$SCRIPT"
    info "Made $SCRIPT executable"
    echo ""
    
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
            ALIAS_CMD="alias dotfiles='git --git-dir=$REPO_PATH --work-tree=$DOTFILES_FOLDER'"
            
            # Check if alias already exists
            if grep -q "alias dotfiles=" "$SHELL_CONFIG" 2>/dev/null; then
                warn "Dotfiles alias already exists in $SHELL_CONFIG"
            else
                echo "" >> "$SHELL_CONFIG"
                echo "# dotfailes alias" >> "$SHELL_CONFIG"
                echo "$ALIAS_CMD" >> "$SHELL_CONFIG"
                success "Added dotfiles alias to $SHELL_CONFIG"
                echo ""
                info "Run 'source $SHELL_CONFIG' to load the alias in your current shell"
            fi
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
