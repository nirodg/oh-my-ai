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

TARGET_DIR="$HOME/.local/bin"
SCRIPT_NAME="ai.sh"

log_info() { echo -e "${BLUE}🤖 $1${NC}"; }
log_success() { echo -e "${GREEN}✓ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
log_error() { echo -e "${RED}✗ $1${NC}"; }

create_directory() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
    fi
}

download_script() {
    log_info "Downloading Oh My AI script..."
    
    # Create the main AI script content
    cat > /tmp/ai_temp.sh << 'EOF'
#!/bin/bash

# Oh My AI - Intelligent Shell Assistant
# Installation: curl -s https://raw.githubusercontent.com/nirodg/oh-my-ai/main/install-ai.sh | bash

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "🤖 Oh My AI - This script should be sourced, not executed directly."
    echo "Usage: source ~/.local/bin/ai.sh"
    exit 1
fi

OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2}"
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
WORK_DIR="$(pwd)"
MAX_FILE_SIZE=100000

BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ -n "$ZSH_VERSION" ]; then
    SHELL_TYPE="zsh"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_TYPE="bash"
else
    SHELL_TYPE="unknown"
fi

check_ollama() {
    if ! command -v ollama &> /dev/null; then
        echo -e "${YELLOW}⚠️  Ollama not found. Install from: https://ollama.ai${NC}"
        return 1
    fi
    if ! ollama list &> /dev/null; then
        echo -e "${YELLOW}⚠️  Ollama service not running. Start with: ollama serve${NC}"
        return 1
    fi
    return 0
}

read_file() {
    local filepath="$1"
    local abs_path=$(realpath "$filepath" 2>/dev/null)
    
    if [ $? -ne 0 ] || [ ! -f "$abs_path" ] || [ ! -r "$abs_path" ]; then
        echo -e "${RED}✗ Cannot read file: $filepath${NC}" >&2
        return 1
    fi
    
    if [[ "$abs_path" != "$WORK_DIR"* ]]; then
        echo -e "${RED}✗ Access denied: File outside work directory${NC}" >&2
        return 1
    fi
    
    local size=$(stat -f%z "$abs_path" 2>/dev/null || stat -c%s "$abs_path" 2>/dev/null)
    if [ "$size" -gt "$MAX_FILE_SIZE" ]; then
        head -c $MAX_FILE_SIZE "$abs_path"
    else
        cat "$abs_path"
    fi
}

gather_context() {
    local context=""
    context+="Working directory: $WORK_DIR\n"
    context+="Current directory: $(pwd)\n"
    context+="Files: $(ls -la 2>/dev/null | head -20)\n\n"
    context+="Command history (last 10):\n"
    context+="$(history 10 2>/dev/null || echo 'History not available')\n\n"
    context+="OS: $(uname -s)\nShell: $SHELL\nUser: $USER\n"
    
    if git rev-parse --git-dir > /dev/null 2>&1; then
        context+="Git branch: $(git branch --show-current 2>/dev/null)\n"
        context+="Git status:\n$(git status -s 2>/dev/null)\n"
    fi
    
    echo -e "$context"
}

is_safe_command() {
    local cmd="$1"
    local dangerous_patterns=("rm -rf /" "dd if=" "mkfs" "> /dev/sda" "mv /* ")
    
    for pattern in "${dangerous_patterns[@]}"; do
        if [[ "$cmd" == *"$pattern"* ]]; then
            echo -e "${RED}⛔ Dangerous command blocked${NC}"
            return 1
        fi
    done
    
    if [[ "$cmd" == *"cd /"* ]] || [[ "$cmd" == *"cd ~"* ]]; then
        echo -e "${RED}⛔ Cannot leave work directory${NC}"
        return 1
    fi
    
    return 0
}

ai() {
    if [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        echo -e "${CYAN}🤖 Oh My AI - Available Commands:${NC}"
        echo "  ai <question>          - Ask anything"
        echo "  ai explain             - Explain last command"
        echo "  ai debug               - Debug failed command"
        echo "  readfile <file>        - Analyze a file"
        echo "  compare <f1> <f2>      - Compare files"
        return 0
    fi
    
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: ai <your question>${NC}"
        echo "Examples: ai what does this do?, ai explain, ai debug"
        return 1
    fi
    
    if ! check_ollama; then
        return 1
    fi
    
    local full_query="$*"
    local context=$(gather_context)
    
    echo -e "${BLUE}🤖 Processing your request...${NC}"
    
    local prompt="You are a helpful shell assistant. Context:\n$context\n\nUser request: $full_query\n\nProvide helpful, concise response:"
    
    local response=$(printf '%s' "$prompt" | ollama run "$OLLAMA_MODEL" 2>/dev/null)
    
    if [ -z "$response" ]; then
        echo -e "${RED}✗ Failed to get response from Ollama${NC}"
        return 1
    fi
    
    echo "$response"
    echo -e "\n${GREEN}───────────────────────────────${NC}"
}

readfile() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: readfile <filename> [question]${NC}"
        return 1
    fi
    
    local content=$(read_file "$1")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local question="${*:2}"
    local prompt="File content:\n$content\n\n"
    
    if [ -z "$question" ]; then
        prompt+="Analyze this file and explain what it does:"
    else
        prompt+="$question"
    fi
    
    echo -e "${CYAN}📖 Analyzing $1...${NC}"
    printf '%s' "$prompt" | ollama run "$OLLAMA_MODEL"
}

explain() {
    local last_cmd=$(history | tail -n 2 | head -n 1 | sed 's/^[ ]*[0-9]*[ ]*//' 2>/dev/null)
    
    if [ -z "$last_cmd" ]; then
        echo "No recent command to explain"
        return 1
    fi
    
    echo -e "${BLUE}💡 Explaining: $last_cmd${NC}"
    ollama run "$OLLAMA_MODEL" "Explain what this shell command does and its purpose: $last_cmd"
}

debug() {
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "Last command succeeded"
        return 0
    fi
    
    local last_cmd=$(history | tail -n 2 | head -n 1 | sed 's/^[ ]*[0-9]*[ ]*//' 2>/dev/null)
    
    echo -e "${RED}🐛 Debugging (exit: $exit_code): $last_cmd${NC}"
    ollama run "$OLLAMA_MODEL" "This command failed with exit code $exit_code: $last_cmd. Explain why it might have failed and suggest a fix:"
}

if check_ollama; then
    echo -e "${GREEN}✓ Oh My AI loaded! Type 'ai help' for help.${NC}"
    
    if [ "$SHELL_TYPE" = "zsh" ]; then
        echo -e "${CYAN}Zsh features: tab completion, keybindings${NC}"
    fi
fi

export -f ai readfile explain debug 2>/dev/null
EOF

    echo "/tmp/ai_temp.sh"
}

install_script() {
    local temp_file="$1"
    local target_file="$TARGET_DIR/$SCRIPT_NAME"
    
    chmod +x "$temp_file"
    cp "$temp_file" "$target_file"
    log_success "Installed to: $target_file"
}

check_path() {
    if ! echo "$PATH" | tr ':' '\n' | grep -q "^$TARGET_DIR$"; then
        log_warning "Adding $TARGET_DIR to PATH..."
        
        if [ -n "$BASH_VERSION" ]; then
            echo "export PATH=\"$TARGET_DIR:\$PATH\"" >> "$HOME/.bashrc"
            log_success "Added to ~/.bashrc - run: source ~/.bashrc"
        elif [ -n "$ZSH_VERSION" ]; then
            echo "export PATH=\"$TARGET_DIR:\$PATH\"" >> "$HOME/.zshrc"
            log_success "Added to ~/.zshrc - run: source ~/.zshrc"
        fi
    fi
}

setup_ollama() {
    if ! command -v ollama &> /dev/null; then
        log_warning "Ollama not found - required for AI features"
        echo ""
        echo "To install Ollama:"
        echo "  curl -fsSL https://ollama.ai/install.sh | sh"
        echo ""
        read -p "Install Ollama now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installing Ollama..."
            curl -fsSL https://ollama.ai/install.sh | sh
        fi
    fi
}

main() {
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}           Oh My AI Installer           ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
    
    create_directory "$TARGET_DIR"
    
    local script_file=$(download_script)
    install_script "$script_file"
    
    check_path
    setup_ollama
    
    echo ""
    log_success "🎉 Installation Complete!"
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Reload shell: source ~/.bashrc (or ~/.zshrc)"
    echo "  2. Test: ai help"
    echo "  3. Ensure Ollama is running: ollama serve"
    echo ""
    echo -e "${GREEN}Enjoy your AI-powered shell! 🚀${NC}"
}

main "$@"