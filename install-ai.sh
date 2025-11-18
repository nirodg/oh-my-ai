#!/bin/bash

# install-ai.sh - Auto-installer for AI Shell Assistant
# Usage: curl -s https://raw.githubusercontent.com/yourusername/super-bash/main/install-ai.sh | bash

set -e

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://raw.githubusercontent.com/yourusername/super-bash/main"
SCRIPT_NAME="oh-my-ai.sh"
INSTALL_NAME="ai.sh"
TARGET_DIR="$HOME/.local/bin"
BACKUP_DIR="$HOME/.local/bin/backups"

# Print colored output
log_info() { echo -e "${BLUE}🤖 $1${NC}"; }
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}"; }

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Detect shell type
detect_shell() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    elif [ -n "$BASH_VERSION" ]; then
        echo "bash"
    else
        echo "unknown"
    fi
}

# Create directory if it doesn't exist
create_directory() {
    if [ ! -d "$1" ]; then
        log_info "Creating directory: $1"
        mkdir -p "$1"
    fi
}

# Backup existing installation
backup_existing() {
    local target="$TARGET_DIR/$INSTALL_NAME"
    if [ -f "$target" ] || [ -L "$target" ]; then
        create_directory "$BACKUP_DIR"
        local backup_name="$BACKUP_DIR/${INSTALL_NAME}.backup.$(date +%Y%m%d_%H%M%S)"
        log_warning "Backing up existing installation to: $backup_name"
        cp "$target" "$backup_name"
    fi
}

# Download the script
download_script() {
    local download_url="$REPO_URL/$SCRIPT_NAME"
    local temp_file="/tmp/${SCRIPT_NAME}.$$"
    
    log_info "Downloading AI assistant from GitHub..."
    
    if command_exists curl; then
        if curl -s -f -L "$download_url" -o "$temp_file"; then
            log_success "Download completed"
            echo "$temp_file"
        else
            log_error "Failed to download script from: $download_url"
            return 1
        fi
    elif command_exists wget; then
        if wget -q "$download_url" -O "$temp_file"; then
            log_success "Download completed"
            echo "$temp_file"
        else
            log_error "Failed to download script from: $download_url"
            return 1
        fi
    else
        log_error "Neither curl nor wget found. Please install one of them."
        return 1
    fi
}

# Validate the downloaded script
validate_script() {
    local script_path="$1"
    
    if [ ! -f "$script_path" ]; then
        log_error "Downloaded file not found"
        return 1
    fi
    
    if [ ! -s "$script_path" ]; then
        log_error "Downloaded file is empty"
        return 1
    fi
    
    # Basic syntax check
    if ! bash -n "$script_path" 2>/dev/null; then
        log_warning "Basic syntax check failed, but continuing installation..."
    fi
    
    return 0
}

# Install the script
install_script() {
    local temp_file="$1"
    local target_file="$TARGET_DIR/$INSTALL_NAME"
    
    # Make the script executable
    chmod +x "$temp_file"
    
    # Create symlink
    log_info "Creating symbolic link in: $TARGET_DIR"
    ln -sf "$temp_file" "$target_file"
    
    # Move temp file to persistent location
    local persistent_location="$HOME/.local/share/ai-assistant/$SCRIPT_NAME"
    create_directory "$(dirname "$persistent_location")"
    mv "$temp_file" "$persistent_location"
    
    # Update symlink to point to persistent location
    ln -sf "$persistent_location" "$target_file"
    
    log_success "Script installed at: $persistent_location"
    log_success "Symbolic link created: $target_file"
}

# Check PATH configuration
check_path_configuration() {
    local shell_type=$(detect_shell)
    local path_configured=false
    
    # Check if ~/.local/bin is in PATH
    if echo "$PATH" | tr ':' '\n' | grep -q "^$TARGET_DIR$"; then
        path_configured=true
    fi
    
    if [ "$path_configured" = false ]; then
        log_warning "$TARGET_DIR is not in your PATH"
        
        if [ "$shell_type" = "bash" ]; then
            local bashrc="$HOME/.bashrc"
            log_info "Adding $TARGET_DIR to PATH in $bashrc"
            echo "export PATH=\"$TARGET_DIR:\$PATH\"" >> "$bashrc"
            log_success "Updated $bashrc - please run: source $bashrc"
        elif [ "$shell_type" = "zsh" ]; then
            local zshrc="$HOME/.zshrc"
            log_info "Adding $TARGET_DIR to PATH in $zshrc"
            echo "export PATH=\"$TARGET_DIR:\$PATH\"" >> "$zshrc"
            log_success "Updated $zshrc - please run: source $zshrc"
        fi
    else
        log_success "$TARGET_DIR is already in PATH"
    fi
}

# Test installation
test_installation() {
    log_info "Testing installation..."
    
    if command_exists "$INSTALL_NAME"; then
        log_success "Installation verified - '$(command -v "$INSTALL_NAME")'"
        return 0
    else
        log_error "Installation test failed - command not found"
        return 1
    fi
}

# Setup Ollama if not present
setup_ollama_if_needed() {
    if ! command_exists ollama && ! docker ps -a 2>/dev/null | grep -q ollama; then
        log_warning "Ollama not found. It's required for the AI assistant."
        echo ""
        log_info "You can install Ollama by:"
        echo "  1. Automatic: curl -fsSL https://ollama.ai/install.sh | sh"
        echo "  2. Docker:    docker run -d --name ollama -p 11434:11434 ollama/ollama"
        echo "  3. Manual:    Visit https://ollama.ai/download"
        echo ""
        read -p "Would you like to install Ollama now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installing Ollama..."
            curl -fsSL https://ollama.ai/install.sh | sh
        fi
    else
        log_success "Ollama is available"
    fi
}

# Show post-installation instructions
show_post_install() {
    local shell_type=$(detect_shell)
    
    echo ""
    log_success "🎉 Installation Complete!"
    echo ""
    log_info "Next steps:"
    echo "  1. Reload your shell configuration:"
    
    if [ "$shell_type" = "bash" ]; then
        echo "     source ~/.bashrc"
    elif [ "$shell_type" = "zsh" ]; then
        echo "     source ~/.zshrc"
    fi
    
    echo ""
    echo "  2. Start using the AI assistant:"
    echo "     ai --help"
    echo ""
    echo "  3. Examples:"
    echo "     ai what does this script do?"
    echo "     ai find all .log files"
    echo "     ai explain the last command"
    echo ""
    
    if [ "$shell_type" = "zsh" ]; then
        log_info "Zsh users get enhanced features:"
        echo "  • Tab completion for files and commands"
        echo "  • Keybindings (Alt+H for help, Alt+S for suggestions)"
        echo "  • Smart autocomplete"
    fi
}

# Main installation function
main() {
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           AI Shell Assistant Installer           ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
    
    log_info "Shell detected: $(detect_shell)"
    log_info "Install directory: $TARGET_DIR"
    echo ""
    
    # Create target directory
    create_directory "$TARGET_DIR"
    
    # Backup existing installation
    backup_existing
    
    # Download script
    local temp_file=$(download_script) || exit 1
    
    # Validate script
    validate_script "$temp_file" || exit 1
    
    # Install script
    install_script "$temp_file"
    
    # Check PATH
    check_path_configuration
    
    # Test installation
    test_installation || exit 1
    
    # Setup Ollama if needed
    setup_ollama_if_needed
    
    # Show post-install instructions
    show_post_install
}

# Run main function
main "$@"
