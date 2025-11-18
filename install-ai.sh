#!/bin/bash

# install-ai.sh - Auto-installer for AI Shell Assistant
set -e

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
REPO_URL="https://raw.githubusercontent.com/nirodg/oh-my-ai/main"
MAIN_SCRIPT="oh-my-ai.sh"
INSTALL_NAME="ai.sh"
TARGET_DIR="$HOME/.local/bin"

log_info() { echo -e "${BLUE}🤖 $1${NC}" >&2; }
log_success() { echo -e "${GREEN}✓ $1${NC}" >&2; }
log_warning() { echo -e "${YELLOW}⚠ $1${NC}" >&2; }
log_error() { echo -e "${RED}✗ $1${NC}" >&2; }

create_directory() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
    fi
}

download_script() {
    local download_url="$REPO_URL/$MAIN_SCRIPT"
    local temp_file="/tmp/ai_install_$$.sh"
    
    # Log to stderr so it doesn't interfere with the file path output
    log_info "Downloading Oh My AI from GitHub..." >&2
    log_info "URL: $download_url" >&2
    
    if command -v curl > /dev/null 2>&1; then
        log_info "Using curl to download..." >&2
        if curl -s -f -L "$download_url" -o "$temp_file" 2>/dev/null; then
            log_success "Download completed successfully" >&2
            echo "$temp_file"
            return 0
        else
            log_error "curl failed to download from: $download_url" >&2
            return 1
        fi
    elif command -v wget > /dev/null 2>&1; then
        log_info "Using wget to download..." >&2
        if wget -q "$download_url" -O "$temp_file" 2>/dev/null; then
            log_success "Download completed successfully" >&2
            echo "$temp_file"
            return 0
        else
            log_error "wget failed to download from: $download_url" >&2
            return 1
        fi
    else
        log_error "Neither curl nor wget found. Please install one of them." >&2
        return 1
    fi
}

validate_script() {
    local script_path="$1"
    
    log_info "Validating downloaded script: $script_path" >&2
    
    if [ ! -f "$script_path" ]; then
        log_error "Downloaded file not found at: $script_path" >&2
        return 1
    fi
    
    if [ ! -s "$script_path" ]; then
        log_error "Downloaded file is empty" >&2
        return 1
    fi
    
    # Check file size
    local file_size=$(wc -c < "$script_path" 2>/dev/null || echo "0")
    if [ "$file_size" -lt 100 ]; then
        log_error "Downloaded file is too small ($file_size bytes)" >&2
        return 1
    fi
    
    # Check if it contains our expected content
    if ! grep -q "Oh My AI" "$script_path" 2>/dev/null; then
        log_warning "File may not contain expected content, but continuing..." >&2
    fi
    
    log_success "Script validation passed ($file_size bytes)" >&2
    return 0
}

install_script() {
    local source_file="$1"
    local target_file="$TARGET_DIR/$INSTALL_NAME"
    
    log_info "Installing script to: $target_file" >&2
    
    # Make executable
    chmod +x "$source_file"
    
    # Copy to target location
    cp "$source_file" "$target_file"
    
    log_success "Installed to: $target_file" >&2

    source $target_file
}

check_path_configuration() {
    log_info "Checking PATH configuration..." >&2
    
    if echo "$PATH" | tr ':' '\n' | grep -q "^$TARGET_DIR$"; then
        log_success "$TARGET_DIR is in PATH" >&2
        return 0
    else
        log_warning "$TARGET_DIR is not in your PATH" >&2
        
        # Detect shell and update appropriate config file
        if [ -n "$BASH_VERSION" ]; then
            local config_file="$HOME/.bashrc"
            log_info "Adding to $config_file" >&2
            echo "# Added by Oh My AI installer" >> "$config_file"
            echo "export PATH=\"$TARGET_DIR:\$PATH\"" >> "$config_file"
            log_success "Updated $config_file - run: source $config_file" >&2
            
        elif [ -n "$ZSH_VERSION" ]; then
            local config_file="$HOME/.zshrc"
            log_info "Adding to $config_file" >&2
            echo "# Added by Oh My AI installer" >> "$config_file"
            echo "export PATH=\"$TARGET_DIR:\$PATH\"" >> "$config_file"
            log_success "Updated $config_file - run: source $config_file" >&2
        else
            log_warning "Please add this to your shell configuration:" >&2
            echo "export PATH=\"$TARGET_DIR:\$PATH\"" >&2
        fi
        return 1
    fi
}

setup_ollama_if_needed() {
    log_info "Checking Ollama installation..." >&2
    
    if command -v ollama > /dev/null 2>&1; then
        log_success "Ollama is installed" >&2
        if ollama list > /dev/null 2>&1; then
            log_success "Ollama service is running" >&2
        else
            log_warning "Ollama service is not running" >&2
            echo "Start it with: ollama serve" >&2
        fi
    else
        log_warning "Ollama not found - required for AI features" >&2
        echo "" >&2
        echo "To install Ollama:" >&2
        echo "  curl -fsSL https://ollama.ai/install.sh | sh" >&2
        echo "" >&2
        read -p "Would you like to install Ollama now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installing Ollama..." >&2
            curl -fsSL https://ollama.ai/install.sh | sh
        else
            log_info "You can install Ollama later from: https://ollama.ai" >&2
        fi
    fi
}

test_installation() {
    log_info "Testing installation..." >&2
    
    if [ -f "$TARGET_DIR/$INSTALL_NAME" ]; then
        log_success "Script installed successfully at: $TARGET_DIR/$INSTALL_NAME" >&2
        return 0
    else
        log_error "Installation test failed - script not found" >&2
        return 1
    fi
}

show_post_install() {
    echo ""
    log_success "🎉 Installation Complete!"
    echo ""
    log_info "Next steps:"
    echo "  1. Add this to your shell configuration:"
    echo "     source $TARGET_DIR/$INSTALL_NAME"
    echo ""
    echo "  2. Or add it permanently to your ~/.bashrc or ~/.zshrc:"
    echo "     echo 'source $TARGET_DIR/$INSTALL_NAME' >> ~/.bashrc"
    echo ""
    echo "  3. Then reload your shell:"
    echo "     source ~/.bashrc  # or source ~/.zshrc"
    echo ""
    echo "  4. Start using:"
    echo "     ai help"
    echo ""
    log_info "Examples:"
    echo "  ai what does this script do?"
    echo "  ai explain the last command"
    echo "  readfile script.sh"
    echo "  debug"
}

main() {
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           Oh My AI Installer           ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
    
    log_info "Target directory: $TARGET_DIR"
    log_info "Repository: $REPO_URL"
    echo ""
    
    # Create target directory
    create_directory "$TARGET_DIR"
    
    # Download the main script
    log_info "Starting download process..."
    local downloaded_file
    downloaded_file=$(download_script)
    local download_result=$?
    
    if [ $download_result -ne 0 ] || [ -z "$downloaded_file" ]; then
        log_error "Failed to download the script"
        echo ""
        log_info "You can try manual installation:"
        echo "  curl -s -L $REPO_URL/$MAIN_SCRIPT -o $TARGET_DIR/$INSTALL_NAME"
        echo "  chmod +x $TARGET_DIR/$INSTALL_NAME"
        echo "  echo 'source $TARGET_DIR/$INSTALL_NAME' >> ~/.bashrc"
        exit 1
    fi
    
    log_info "Downloaded to: $downloaded_file"
    
    # Validate the downloaded script
    if ! validate_script "$downloaded_file"; then
        log_error "Script validation failed"
        rm -f "$downloaded_file"
        exit 1
    fi
    
    # Install the script
    install_script "$downloaded_file"
    
    # Clean up temp file
    rm -f "$downloaded_file"
    
    # Check and configure PATH
    check_path_configuration
    
    # Test installation
    test_installation || exit 1
    
    # Setup Ollama
    setup_ollama_if_needed
    
    # Show post-install instructions
    show_post_install
}

# Run main function
main "$@"