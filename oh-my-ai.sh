#!/bin/bash

#!/bin/bash

# AI Shell Assistant - Ollama-powered Bash/Zsh Assistant
# Installation: curl -s https://raw.githubusercontent.com/yourusername/super-bash/main/install-ai.sh | bash
# Repository: https://github.com/yourusername/super-bash

# Check if script is being run directly or sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "🤖 AI Shell Assistant"
    echo ""
    echo "This script is designed to be sourced, not executed directly."
    echo ""
    echo "To install:"
    echo "  curl -s https://raw.githubusercontent.com/yourusername/super-bash/main/install-ai.sh | bash"
    echo ""
    echo "Then add to your shell:"
    echo "  source ~/.local/bin/ai.sh"
    echo ""
    exit 1
fi

# ai.sh - Ollama-powered Bash/Zsh Assistant
# A smart shell assistant that understands your environment and can execute commands safely

# Configuration
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2}"
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
HISTORY_LINES=20
WORK_DIR="$(pwd)"  # Lock to the directory where helper was sourced
MAX_FILE_SIZE=100000  # Max file size to read (100KB)
AI_CONFIG_FILE="${HOME}/.ai_sh_config"

# Colors for output
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Detect shell type
if [ -n "$ZSH_VERSION" ]; then
    SHELL_TYPE="zsh"
elif [ -n "$BASH_VERSION" ]; then
    SHELL_TYPE="bash"
else
    SHELL_TYPE="unknown"
fi

# ============================================================================
# OLLAMA SETUP AND CONNECTIVITY
# ============================================================================

# Load saved configuration
load_config() {
    if [ -f "$AI_CONFIG_FILE" ]; then
        source "$AI_CONFIG_FILE"
    fi
}

# Save configuration
save_config() {
    cat > "$AI_CONFIG_FILE" << EOF
# AI.sh Configuration
export OLLAMA_HOST="$OLLAMA_HOST"
export OLLAMA_MODEL="$OLLAMA_MODEL"
EOF
    echo -e "${GREEN}✓ Configuration saved to $AI_CONFIG_FILE${NC}"
}

# Check if Ollama is accessible
check_ollama_connectivity() {
    local host="$1"
    if curl -s --connect-timeout 3 "$host/api/tags" > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Ask user for custom Ollama host
ask_custom_host() {
    echo -e "${YELLOW}Do you have Ollama running on a different host/port? (y/N)${NC}"
    read -r response
    
    if [[ "$response" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Enter Ollama host (format: http://host:port or https://host:port):${NC}"
        read -r custom_host
        
        # Validate format
        if [[ ! "$custom_host" =~ ^https?:// ]]; then
            custom_host="http://$custom_host"
        fi
        
        echo -e "${BLUE}Testing connection to $custom_host...${NC}"
        if check_ollama_connectivity "$custom_host"; then
            OLLAMA_HOST="$custom_host"
            export OLLAMA_HOST
            save_config
            echo -e "${GREEN}✓ Connected to Ollama at $OLLAMA_HOST${NC}"
            return 0
        else
            echo -e "${RED}✗ Cannot connect to $custom_host${NC}"
            return 1
        fi
    fi
    return 1
}

# Deploy Ollama via Docker
deploy_ollama_docker() {
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}🐳 Ollama Docker Deployment${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗ Docker is not installed${NC}"
        echo -e "${YELLOW}Please install Docker from: https://docs.docker.com/get-docker/${NC}"
        return 1
    fi
    
    # Check if Docker daemon is running
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}✗ Docker daemon is not running${NC}"
        echo -e "${YELLOW}Please start Docker and try again${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Docker is installed and running${NC}"
    echo ""
    
    # Check if ollama container already exists
    if docker ps -a --format '{{.Names}}' | grep -q '^ollama$'; then
        echo -e "${YELLOW}Found existing 'ollama' container${NC}"
        
        # Check if it's running
        if docker ps --format '{{.Names}}' | grep -q '^ollama$'; then
            echo -e "${GREEN}✓ Ollama container is already running${NC}"
            OLLAMA_HOST="http://localhost:11434"
            export OLLAMA_HOST
            save_config
            return 0
        else
            echo -e "${BLUE}Starting existing Ollama container...${NC}"
            docker start ollama
            sleep 3
            
            if check_ollama_connectivity "http://localhost:11434"; then
                echo -e "${GREEN}✓ Ollama container started successfully${NC}"
                OLLAMA_HOST="http://localhost:11434"
                export OLLAMA_HOST
                save_config
                return 0
            fi
        fi
    fi
    
    # Ask for confirmation to deploy new container
    echo -e "${YELLOW}Deploy Ollama in Docker container? (Y/n)${NC}"
    read -r response
    
    if [[ "$response" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Deployment cancelled${NC}"
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}🚀 Deploying Ollama container...${NC}"
    echo -e "${CYAN}This may take a few minutes on first run...${NC}"
    echo ""
    
    # Run Ollama container
    if docker run -d \
        --name ollama \
        -p 11434:11434 \
        -v ollama:/root/.ollama \
        --restart unless-stopped \
        ollama/ollama; then
        
        echo ""
        echo -e "${GREEN}✓ Ollama container deployed successfully${NC}"
        echo -e "${BLUE}Waiting for Ollama to start...${NC}"
        
        # Wait for Ollama to be ready
        local max_attempts=30
        local attempt=0
        while [ $attempt -lt $max_attempts ]; do
            if check_ollama_connectivity "http://localhost:11434"; then
                echo -e "${GREEN}✓ Ollama is ready!${NC}"
                break
            fi
            sleep 2
            attempt=$((attempt + 1))
            echo -n "."
        done
        echo ""
        
        if [ $attempt -eq $max_attempts ]; then
            echo -e "${RED}✗ Ollama failed to start in time${NC}"
            return 1
        fi
        
        OLLAMA_HOST="http://localhost:11434"
        export OLLAMA_HOST
        save_config
        
        # Pull the default model
        echo ""
        echo -e "${BLUE}📦 Pulling model: $OLLAMA_MODEL${NC}"
        echo -e "${CYAN}This will download ~2GB on first run...${NC}"
        docker exec ollama ollama pull "$OLLAMA_MODEL"
        
        echo ""
        echo -e "${GREEN}✓ Setup complete!${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to deploy Ollama container${NC}"
        return 1
    fi
}

# Main setup function
setup_ollama() {
    load_config
    
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} 🤖 AI.sh Ollama Setup${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
    
    # Check if Ollama is already accessible
    echo -e "${BLUE}Checking for Ollama at $OLLAMA_HOST...${NC}"
    if check_ollama_connectivity "$OLLAMA_HOST"; then
        echo -e "${GREEN}✓ Ollama is running at $OLLAMA_HOST${NC}"
        
        # Check if model is available
        if curl -s "$OLLAMA_HOST/api/tags" | grep -q "\"name\":\"$OLLAMA_MODEL\""; then
            echo -e "${GREEN}✓ Model '$OLLAMA_MODEL' is available${NC}"
        else
            echo -e "${YELLOW}⚠ Model '$OLLAMA_MODEL' not found${NC}"
            echo -e "${BLUE}Pulling model...${NC}"
            if command -v ollama &> /dev/null; then
                ollama pull "$OLLAMA_MODEL"
            else
                docker exec ollama ollama pull "$OLLAMA_MODEL" 2>/dev/null || true
            fi
        fi
        
        return 0
    fi
    
    echo -e "${YELLOW}✗ Ollama is not accessible at $OLLAMA_HOST${NC}"
    echo ""
    
    # Ask if running on different host
    if ask_custom_host; then
        return 0
    fi
    
    # Offer Docker deployment
    echo ""
    echo -e "${YELLOW}Would you like to deploy Ollama using Docker? (Y/n)${NC}"
    read -r response
    
    if [[ ! "$response" =~ ^[Nn]$ ]]; then
        if deploy_ollama_docker; then
            return 0
        fi
    fi
    
    echo ""
    echo -e "${RED}✗ Ollama setup failed${NC}"
    echo -e "${YELLOW}Please install Ollama manually from: https://ollama.ai${NC}"
    echo -e "${YELLOW}Or run: curl -fsSL https://ollama.ai/install.sh | sh${NC}"
    return 1
}

# Function to safely read a file
read_file() {
    local filepath="$1"
    
    # Convert to absolute path and check if within work directory
    local abs_path=$(realpath "$filepath" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${RED}✗ File not found: $filepath${NC}" >&2
        return 1
    fi
    
    # Security check: must be within work directory
    if [[ "$abs_path" != "$WORK_DIR"* ]]; then
        echo -e "${RED}✗ Access denied: File outside work directory${NC}" >&2
        echo -e "${YELLOW}  Work dir: $WORK_DIR${NC}" >&2
        echo -e "${YELLOW}  Requested: $abs_path${NC}" >&2
        return 1
    fi
    
    # Check if file exists and is readable
    if [ ! -f "$abs_path" ]; then
        echo -e "${RED}✗ Not a file: $filepath${NC}" >&2
        return 1
    fi
    
    if [ ! -r "$abs_path" ]; then
        echo -e "${RED}✗ Cannot read file: $filepath${NC}" >&2
        return 1
    fi
    
    # Check file size
    local size=$(stat -f%z "$abs_path" 2>/dev/null || stat -c%s "$abs_path" 2>/dev/null)
    if [ "$size" -gt "$MAX_FILE_SIZE" ]; then
        echo -e "${YELLOW}⚠ File too large ($size bytes, max $MAX_FILE_SIZE)${NC}" >&2
        echo -e "${YELLOW}  Reading first $(($MAX_FILE_SIZE / 1000))KB only${NC}" >&2
        head -c $MAX_FILE_SIZE "$abs_path"
        return 0
    fi
    
    # Read and return file content
    cat "$abs_path"
}

# Read multiple files and format for AI context
read_files_for_context() {
    local files=("$@")
    local context=""
    
    for file in "${files[@]}"; do
        context+="=== File: $file ===\n"
        local content=$(read_file "$file" 2>&1)
        if [ $? -eq 0 ]; then
            context+="$content\n"
        else
            context+="[Error reading file: $content]\n"
        fi
        context+="\n"
    done
    
    echo -e "$context"
}
gather_context() {
    local context=""
    
    # Current directory and contents
    context+="Working directory (locked): $WORK_DIR\n"
    context+="Current directory: $(pwd)\n"
    context+="Files here: $(ls -lah | tail -n +2 | head -20)\n\n"
    
    # Full recent command history with timestamps if available
    context+="Command history (last $HISTORY_LINES commands):\n"
    context+="$(HISTTIMEFORMAT='%F %T ' history | tail -n $HISTORY_LINES | cat -n)\n\n"
    
    # System info
    context+="OS: $(uname -s)\n"
    context+="Shell: $SHELL\n"
    context+="User: $USER\n"
    
    # Git context if in a repo
    if git rev-parse --git-dir > /dev/null 2>&1; then
        context+="Git branch: $(git branch --show-current 2>/dev/null)\n"
        context+="Git status:\n$(git status -s)\n"
        context+="Recent commits:\n$(git log --oneline -5 2>/dev/null)\n"
    fi
    
    # Environment variables that might be relevant
    context+="PATH: $PATH\n"
    
    echo -e "$context"
}

# Safety check for commands
is_safe_command() {
    local cmd="$1"
    
    # Block dangerous commands
    local dangerous_patterns=(
        "rm -rf /"
        "dd if="
        "mkfs"
        ":(){:|:&};:"  # Fork bomb
        "> /dev/sda"
        "mv /* "
        "chmod -R 777 /"
        "chown -R"
    )
    
    for pattern in "${dangerous_patterns[@]}"; do
        if [[ "$cmd" == *"$pattern"* ]]; then
            echo -e "${RED}⛔ Blocked: Dangerous command pattern detected${NC}"
            return 1
        fi
    done
    
    # Check if command tries to escape work directory
    if [[ "$cmd" == *"cd /"* ]] || [[ "$cmd" == *"cd ~"* ]]; then
        echo -e "${RED}⛔ Blocked: Cannot leave work directory ($WORK_DIR)${NC}"
        return 1
    fi
    
    # Block sudo/root escalation
    if [[ "$cmd" == sudo* ]] || [[ "$cmd" == su* ]]; then
        echo -e "${RED}⛔ Blocked: Root privileges not allowed${NC}"
        return 1
    fi
    
    return 0
}

# Execute a command safely within work directory
safe_execute() {
    local cmd="$1"
    local confirm="${2:-yes}"  # Require confirmation by default
    
    if ! is_safe_command "$cmd"; then
        return 1
    fi
    
    if [ "$confirm" = "yes" ]; then
        echo -e "${YELLOW}Execute: $cmd${NC}"
        echo -n "Confirm? (y/N): "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Cancelled"
            return 1
        fi
    fi
    
    # Execute in subshell locked to work directory
    (
        cd "$WORK_DIR" || exit 1
        eval "$cmd"
    )
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ Command completed successfully${NC}"
    else
        echo -e "${RED}✗ Command failed with exit code: $exit_code${NC}"
    fi
    
    return $exit_code
}
# Main AI helper function with intelligent routing
ai() {
    # Show help if requested
    if [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        ai_help
        return 0
    fi
    
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: ai <your question or request>${NC}"
        echo ""
        echo -e "Type ${BLUE}ai help${NC} for full documentation"
        echo ""
        echo "Examples:"
        echo "  ai what does script.sh do?"
        echo "  ai compare old.py and new.py"
        echo "  ai create a backup of all logs"
        echo "  ai why did that fail?"
        echo "  ai what have I been working on?"
        return 1
    fi
    
    # Capture the full query, preserving all special characters
    local full_query="$*"
    
    # Escape special characters for safe processing
    local escaped_query=$(printf '%s' "$full_query" | sed 's/[]\/$*.^[]/\\&/g')
    
    local context=$(gather_context)
    
    # Detect intent and route to appropriate function
    # We pass the query safely to avoid any injection issues
    local intent_prompt="Analyze this user request and respond with ONLY ONE WORD indicating the intent:

User request: $full_query

Context: They are in a bash shell, recently ran these commands:
$(history | tail -n 5 | sed 's/^[ ]*[0-9]*[ ]*//')

Current directory files: $(ls -1 | head -10 | tr '\n' ' ')

Possible intents:
- READFILE: wants to read/analyze/understand a single file (phrases like: 'what does X do', 'show me X', 'read X', 'explain X' where X is a filename)
- COMPARE: wants to compare multiple files (contains: compare, diff, difference, vs, versus + multiple filenames)
- BUILD: wants to create/execute a NEW command (phrases like: 'create a script', 'make a backup', 'find all files', 'run a command')
- EXPLAIN: wants to explain a PREVIOUS command from history (phrases like: 'explain the last command', 'what did that do', 'explain the previous')
- DEBUG: wants to debug a failed command (contains: why fail, error, wrong, debug, fix)
- ANALYZE: wants workflow analysis (contains: what am i, what have i been, my workflow, analyze history)
- CHAT: general question or needs regular AI assistance

IMPORTANT: If the query mentions a filename that exists and asks about it (like 'what does file.txt do'), respond with READFILE.

Respond with ONLY the intent word."

    echo -e "${BLUE} 🤖 Understanding your request...${NC}"
    
    # Safely pass to ollama using printf to handle special chars
    local intent=$(printf '%s' "$intent_prompt" | ollama run "$OLLAMA_MODEL" 2>/dev/null | tr -d '\n' | tr '[:lower:]' '[:upper:]' | xargs)
    
    # Extract filenames if present - handle special chars in filenames
    local files=()
    # First, try to find any existing files mentioned in the query
    local words_array=($full_query)
    for word in "${words_array[@]}"; do
        # Remove common words and punctuation
        local cleaned_word=$(echo "$word" | sed 's/[?,!.]$//')
        # Check if this word is an existing file
        if [ -f "$cleaned_word" ]; then
            files+=("$cleaned_word")
        fi
    done
    
    case "$intent" in
        READFILE)
            if [ ${#files[@]} -eq 0 ]; then
                # Try to extract filename from query
                echo -e "${CYAN}📖 Detecting file to read...${NC}"
                local extract_prompt="From this request, extract ONLY the filename (nothing else):
$full_query"
                local extracted_file=$(printf '%s' "$extract_prompt" | ollama run "$OLLAMA_MODEL" 2>/dev/null | xargs)
                if [ -f "$extracted_file" ]; then
                    files+=("$extracted_file")
                fi
            fi
            
            if [ ${#files[@]} -gt 0 ]; then
                echo -e "${CYAN}📖 Reading: ${files[0]}${NC}\n"
                local content=$(read_file "${files[0]}")
                if [ $? -ne 0 ]; then
                    return 1
                fi
                
                # Safely remove filename from query
                local question=$(printf '%s' "$full_query" | sed "s|${files[0]}||g" | xargs)
                local prompt="Here is the content of ${files[0]}:

$content

"
                if [ -z "$question" ]; then
                    prompt+="Analyze this file and provide a summary of what it does, its purpose, and any notable features or issues."
                else
                    prompt+="$question"
                fi
                
                echo -e "${BLUE} 🤖 Analyzing file...${NC}\n"
                printf '%s' "$prompt" | ollama run "$OLLAMA_MODEL"
            else
                echo -e "${RED}✗ Could not detect file to read${NC}"
                return 1
            fi
            ;;
            
        COMPARE)
            if [ ${#files[@]} -ge 2 ]; then
                echo -e "${CYAN}📊 Comparing ${#files[@]} files...${NC}\n"
                local file_contents=$(read_files_for_context "${files[@]}")
                local question=$(printf '%s' "$full_query" | sed "s|${files[0]}||g" | sed "s|${files[1]}||g" | xargs)
                
                local prompt="Compare these files:

$file_contents

"
                if [ -z "$question" ]; then
                    prompt+="Provide a detailed comparison highlighting:
1. Key differences
2. Similarities
3. Which version is better and why (if applicable)"
                else
                    prompt+="Focus on: $question"
                fi
                
                echo -e "${BLUE} 🤖 Analyzing differences...${NC}\n"
                printf '%s' "$prompt" | ollama run "$OLLAMA_MODEL"
            else
                echo -e "${RED}✗ Need at least 2 files to compare${NC}"
                return 1
            fi
            ;;
            
        BUILD)
            echo -e "${BLUE}💡 Building command for: ${CYAN}$full_query${NC}\n"
            local build_prompt="Based on this context and history:

$context

The user wants to: $full_query

Suggest a command that:
1. Accomplishes this goal
2. Works in their current environment
3. Is safe to execute

Respond with ONLY the command, no explanation."
            
            local cmd=$(printf '%s' "$build_prompt" | ollama run "$OLLAMA_MODEL")
            
            echo -e "${GREEN}Suggested:${NC} $cmd"
            echo ""
            
            echo -n "Execute this command? (y/N): "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                safe_execute "$cmd" "no"
            fi
            ;;
            
        EXPLAIN)
            local num_back=2
            # Check if query contains a number
            if [[ "$full_query" =~ [0-9]+ ]]; then
                num_back="${BASH_REMATCH[0]}"
            fi
            
            local last_cmd=$(history | tail -n $num_back | head -n 1 | sed 's/^[ ]*[0-9]*[ ]*//')
            
            if [ -z "$last_cmd" ]; then
                echo "No recent command to explain"
                return 1
            fi
            
            echo -e "${BLUE}Explaining: ${YELLOW}$last_cmd${NC}\n"
            
            local prompt="Based on this command history and context:
$context

Explain what this command does and why the user might have run it:
$last_cmd

Be concise but thorough."
            
            printf '%s' "$prompt" | ollama run "$OLLAMA_MODEL"
            ;;
            
        DEBUG)
            local exit_code=$?
            local last_cmd=$(history | tail -n 2 | head -n 1 | sed 's/^[ ]*[0-9]*[ ]*//')
            
            echo -e "${BLUE}🔍 Debugging: ${YELLOW}$last_cmd${NC}\n"
            
            local prompt="Analyze this failed command in context:

$context

Failed command: $last_cmd

Look at the command history to understand what the user was trying to do. Explain:
1. Why it likely failed
2. What they should try instead
3. Any relevant commands from their history

Be specific and actionable."
            
            printf '%s' "$prompt" | ollama run "$OLLAMA_MODEL"
            ;;
            
        ANALYZE)
            echo -e "${BLUE}📊 Analyzing your recent activity...${NC}\n"
            
            local prompt="Analyze this user's command history and current environment:

$context

Request: $full_query

Provide insights about:
- What they're working on
- Patterns in their commands
- Potential issues or improvements
- Suggestions based on their workflow

Be concise and helpful."
            
            printf '%s' "$prompt" | ollama run "$OLLAMA_MODEL"
            ;;
            
        *)
            # Default CHAT mode - include file context if files were mentioned
            if [ ${#files[@]} -gt 0 ]; then
                echo -e "${CYAN}📄 Reading ${#files[@]} file(s)...${NC}"
                local file_context=$(read_files_for_context "${files[@]}")
                context+="\n\nFILE CONTENTS:\n$file_context"
            fi
            
            local full_prompt="You are a helpful bash shell assistant with access to the user's command history and current environment.

CONTEXT:
$context

The user has been working in this environment and their command history shows what they've been doing.

USER REQUEST: $full_query

Analyze their history, files, and context to provide relevant help. If they're asking about previous commands, refer to the numbered history entries. Be concise and practical."
            
            echo -e "${BLUE} 🤖 Thinking...${NC}\n"
            printf '%s' "$full_prompt" | ollama run "$OLLAMA_MODEL"
            ;;
    esac
    
    echo -e "\n${GREEN}───────────────────────────────${NC}"
}

# Quick command suggestions
suggest() {
    local task="$*"
    if [ -z "$task" ]; then
        echo -e "${YELLOW}Usage: suggest <what you want to do>${NC}"
        echo "Example: suggest backup all .txt files"
        return 1
    fi
    
    local context=$(gather_context)
    local prompt="Based on this context:
$context

Suggest a bash command to: $task

Respond with ONLY the command, no explanation unless asked."
    
    echo -e "${BLUE}💡 Suggested command:${NC}"
    ollama run "$OLLAMA_MODEL" "$prompt"
}

# Read and analyze a file
readfile() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: readfile <filepath> [question]${NC}"
        echo "Examples:"
        echo "  readfile script.sh"
        echo "  readfile config.json explain this configuration"
        echo "  readfile app.py find potential bugs"
        return 1
    fi
    
    local filepath="$1"
    shift
    local question="$*"
    
    echo -e "${CYAN}📖 Reading: $filepath${NC}\n"
    
    local content=$(read_file "$filepath")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    local prompt="Here is the content of $filepath:

$content

"
    
    if [ -z "$question" ]; then
        prompt+="Analyze this file and provide a summary of what it does, its purpose, and any notable features or issues."
    else
        prompt+="$question"
    fi
    
    echo -e "${BLUE} 🤖 Analyzing file...${NC}\n"
    ollama run "$OLLAMA_MODEL" "$prompt"
}

# Compare multiple files
compare() {
    if [ $# -lt 2 ]; then
        echo -e "${YELLOW}Usage: compare <file1> <file2> [file3...] [question]${NC}"
        echo "Example: compare old_config.json new_config.json what changed?"
        return 1
    fi
    
    local files=()
    local question=""
    local reading_files=true
    
    for arg in "$@"; do
        if [ -f "$arg" ] && [ "$reading_files" = true ]; then
            files+=("$arg")
        else
            reading_files=false
            question="$question $arg"
        fi
    done
    
    if [ ${#files[@]} -lt 2 ]; then
        echo -e "${RED}Error: Need at least 2 files to compare${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📊 Comparing ${#files[@]} files...${NC}\n"
    
    local file_contents=$(read_files_for_context "${files[@]}")
    
    local prompt="Compare these files:

$file_contents

"
    
    if [ -z "$question" ]; then
        prompt+="Provide a detailed comparison highlighting:
1. Key differences
2. Similarities
3. Which version is better and why (if applicable)"
    else
        prompt+="$question"
    fi
    
    echo -e "${BLUE} 🤖 Analyzing differences...${NC}\n"
    ollama run "$OLLAMA_MODEL" "$prompt"
}

# Explain the last command from history
explain() {
    local num_back="${1:-2}"  # Default to last command
    local last_cmd=$(history | tail -n $num_back | head -n 1 | sed 's/^[ ]*[0-9]*[ ]*//')
    
    if [ -z "$last_cmd" ]; then
        echo "No recent command to explain"
        return 1
    fi
    
    echo -e "${BLUE}Explaining: ${YELLOW}$last_cmd${NC}\n"
    
    local context=$(gather_context)
    local prompt="Based on this command history and context:
$context

Explain what this command does and why the user might have run it:
$last_cmd

Be concise but thorough."
    
    ollama run "$OLLAMA_MODEL" "$prompt"
}

# Debug helper - analyzes history to understand what went wrong
debug() {
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo "Last command succeeded (exit code 0)"
        return 0
    fi
    
    local last_cmd=$(history | tail -n 2 | head -n 1 | sed 's/^[ ]*[0-9]*[ ]*//')
    
    echo -e "${BLUE}Debugging failed command (exit code: $exit_code)${NC}"
    echo -e "${YELLOW}Command: $last_cmd${NC}\n"
    
    local context=$(gather_context)
    local prompt="Analyze this failed command in context:

$context

Failed command (exit $exit_code): $last_cmd

Look at the command history to understand what the user was trying to do. Explain:
1. Why it likely failed
2. What they should try instead
3. Any relevant commands from their history

Be specific and actionable."
    
    ollama run "$OLLAMA_MODEL" "$prompt"
}

# Analyze what the user has been doing
analyze() {
    local focus="${1:-general}"  # general, files, git, errors
    
    echo -e "${BLUE}📊 Analyzing your recent activity...${NC}\n"
    
    local context=$(gather_context)
    local prompt="Analyze this user's command history and current environment:

$context

Focus: $focus

Provide insights about:
- What they're working on
- Patterns in their commands
- Potential issues or improvements
- Suggestions based on their workflow

Be concise and helpful."
    
    ollama run "$OLLAMA_MODEL" "$prompt"
}

# Interactive command builder
build() {
    local goal="$*"
    if [ -z "$goal" ]; then
        echo -e "${YELLOW}Usage: build <what you want to accomplish>${NC}"
        echo "Example: build find and compress all logs older than 30 days"
        return 1
    fi
    
    local context=$(gather_context)
    local prompt="Based on this context and history:

$context

The user wants to: $goal

Suggest a command that:
1. Accomplishes this goal
2. Works in their current environment
3. Is safe to execute

Respond with ONLY the command, no explanation."
    
    echo -e "${BLUE}💡 Building command...${NC}\n"
    local cmd=$(ollama run "$OLLAMA_MODEL" "$prompt")
    
    echo -e "${GREEN}Suggested:${NC} $cmd"
    echo ""
    
    echo -n "Execute this command? (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        safe_execute "$cmd" "no"  # Already confirmed
    fi
}

# Check if Ollama is running
check_ollama() {
    if ! command -v ollama &> /dev/null; then
        echo -e "${YELLOW}⚠️  Ollama not found. Install from: https://ollama.ai${NC}"
        return 1
    fi
    
    if ! ollama list &> /dev/null; then
        echo -e "${YELLOW}⚠️  Ollama service not running. Start it with: ollama serve${NC}"
        return 1
    fi
    
    return 0
}

# Auto-setup message
if check_ollama; then
    echo -e "${GREEN}✓ ai.sh loaded! (${SHELL_TYPE})${NC}"
    echo -e "${BLUE}Work directory:${NC} $WORK_DIR"
    echo ""
    echo -e "${CYAN}Just type:${NC} ${BLUE}ai <anything>${NC}"
    echo ""
    echo -e "Examples:"
    echo -e "  ${BLUE}ai what does script.sh do?${NC}"
    echo -e "  ${BLUE}ai compare config.old and config.new${NC}"
    echo -e "  ${BLUE}ai create a backup of all .txt files${NC}"
    echo -e "  ${BLUE}ai why did that fail?${NC}"
    echo -e "  ${BLUE}ai what have I been working on?${NC}"
    echo ""
    echo -e "${YELLOW}Model:${NC} $OLLAMA_MODEL"
    
    # Setup completions based on shell type
    if [ "$SHELL_TYPE" = "zsh" ]; then
        echo -e "${GREEN}✓ Zsh completions enabled${NC}"
    fi
fi

# Export functions (compatible with both bash and zsh)
if [ "$SHELL_TYPE" = "bash" ]; then
    export -f ai gather_context safe_execute is_safe_command read_file read_files_for_context
fi
# In zsh, functions are automatically available in the current shell context

# ============================================================================
# PROMPT CUSTOMIZATION
# ============================================================================

# Function to show keybindings
ai_help() {
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${GREEN} 🤖 AI Assistant Active${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${YELLOW}Commands:${NC}"
    echo -e "  ${BLUE}ai${NC} <question>          Ask anything"
    echo ""
    echo -e "${YELLOW}Keybindings:${NC}"
    if [ "$SHELL_TYPE" = "zsh" ]; then
        echo -e "  ${BLUE}Alt+H${NC}               Show full help (this screen)"
        echo -e "  ${BLUE}Alt+S${NC}               Smart AI suggestions"
        echo -e "  ${BLUE}Alt+A${NC}               Wrap command with 'ai explain'"
        echo -e "  ${BLUE}Alt+E${NC}               Wrap command with 'ai create'"
        echo -e "  ${BLUE}Tab${NC}                 Autocomplete files and commands"
    fi
    echo -e "  ${BLUE}ai help${NC}             Show this help"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  ai what does script.sh do?"
    echo -e "  ai compare old.py new.py"
    echo -e "  ai create backup of logs"
    echo -e "  ai why did that fail?"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
}

# Add alias for help
alias ai-help='ai_help'

# Modify the prompt to show AI is active
if [ "$SHELL_TYPE" = "zsh" ]; then
    # Save original prompt if not already saved
    if [ -z "$AI_ORIGINAL_PROMPT" ]; then
        export AI_ORIGINAL_PROMPT="$PROMPT"
    fi
    
    # Create AI indicator with icon
    AI_INDICATOR="%F{cyan} 🤖%f "
    
    # Set new prompt with AI indicator
    export PROMPT="${AI_INDICATOR}${AI_ORIGINAL_PROMPT}"
    
    # Also update right prompt to show keybindings hint
    export RPROMPT="%F{240}(Alt+H=help Tab=complete)%f"
    
elif [ "$SHELL_TYPE" = "bash" ]; then
    # Save original PS1 if not already saved
    if [ -z "$AI_ORIGINAL_PS1" ]; then
        export AI_ORIGINAL_PS1="$PS1"
    fi
    
    # Add AI indicator to bash prompt
    export PS1="\[\e[36m\] 🤖\[\e[0m\] $AI_ORIGINAL_PS1"
fi

# Set environment variable to indicate AI is active
export AI_ASSISTANT_ACTIVE="1"

# ============================================================================
# ZSH COMPLETIONS
# ============================================================================

if [ "$SHELL_TYPE" = "zsh" ]; then
    # Enable zsh completion system if not already enabled
    autoload -Uz compinit
    compinit 2>/dev/null
    
    # Define completion function for ai command
    _ai_completion() {
        local -a suggestions
        local current_word="${words[CURRENT]}"
        local full_line="${words[*]:1}"
        local prev_word="${words[CURRENT-1]}"
        
        # Always offer file completion if it looks like we're typing a filename
        # This handles partial filenames like "dele" -> "delete.me"
        if [[ $CURRENT -gt 1 ]]; then
            # After 'ai', complete with files and common actions
            local -a all_completions
            
            # Add file completions
            local -a file_list
            file_list=(${(f)"$(ls -1 2>/dev/null)"})
            for file in $file_list; do
                all_completions+=("$file:file")
            done
            
            # Add action suggestions only on first word after 'ai'
            if [ ${#words[@]} -eq 2 ]; then
                all_completions+=(
                    'what:Ask about something'
                    'how:Get instructions'
                    'explain:Explain a command'
                    'compare:Compare files'
                    'create:Build a command'
                    'find:Search for something'
                    'backup:Create backups'
                    'why:Debug issues'
                    'analyze:Analyze workflow'
                    'read:Read a file'
                    'show:Display information'
                )
            fi
            
            _describe 'completions' all_completions
            return 0
        fi
    }
    
    # Register the completion function with more aggressive file completion
    compdef _ai_completion ai
    
    # Force file completion as fallback
    zstyle ':completion:*:*:ai:*' file-patterns '*:all-files'
    zstyle ':completion:*:*:ai:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
    
    # Add intelligent suggestions based on context
    _ai_suggest_intent() {
        local buffer="$1"
        local suggestions=()
        
        # Detect intent from partial input
        case "$buffer" in
            *"compare"*)
                echo " file1 file2"
                ;;
            *"explain"*|*"what does"*)
                echo " [command or file]"
                ;;
            *"create"*|*"make"*|*"build"*)
                echo " [task description]"
                ;;
            *"find"*|*"search"*)
                echo " [what to find]"
                ;;
            *"backup"*)
                echo " [files to backup]"
                ;;
            *"why"*|*"debug"*)
                echo " [last command failed]"
                ;;
            *"analyze"*)
                echo " [my workflow]"
                ;;
            *"read"*|*"show"*)
                echo " [filename]"
                ;;
        esac
    }
    
    # Add ZSH-specific keybindings
    
    # Alt+H: Show help menu
    ai_help_widget() {
        # Clear current line
        BUFFER=""
        # Show help
        zle push-line
        ai_help
        zle reset-prompt
    }
    zle -N ai_help_widget
    bindkey '^[h' ai_help_widget  # Alt+H
    
    # Alt+S: Show AI suggestion for current buffer (Smart suggestions)
    ai_suggest_widget() {
        local suggestion=$(_ai_suggest_intent "$BUFFER")
        if [ -n "$suggestion" ]; then
            BUFFER="${BUFFER}${suggestion}"
            CURSOR=${#BUFFER}
        else
            # If no suggestion, show a hint
            echo ""
            echo -e "${YELLOW}💡 Type 'ai' followed by your question${NC}"
        fi
        zle reset-prompt
    }
    zle -N ai_suggest_widget
    bindkey '^[s' ai_suggest_widget  # Alt+S
    
    # Alt+A: Wrap current command with 'ai explain'
    ai_explain_widget() {
        if [ -n "$BUFFER" ]; then
            BUFFER="ai explain $BUFFER"
            CURSOR=${#BUFFER}
        fi
        zle reset-prompt
    }
    zle -N ai_explain_widget
    bindkey '^[a' ai_explain_widget  # Alt+A
    
    # Alt+E: Execute AI command suggestion
    ai_execute_widget() {
        if [ -n "$BUFFER" ] && [[ ! "$BUFFER" =~ ^ai ]]; then
            BUFFER="ai create $BUFFER"
            CURSOR=${#BUFFER}
        fi
        zle reset-prompt
    }
    zle -N ai_execute_widget
    bindkey '^[e' ai_execute_widget  # Alt+E
    
    echo ""
    echo -e "${CYAN}Zsh Keybindings:${NC}"
    echo -e "  ${BLUE}Alt+H${NC}      - Show full help"
    echo -e "  ${BLUE}Alt+S${NC}      - Smart AI suggestions"
    echo -e "  ${BLUE}Alt+A${NC}      - Wrap with 'ai explain'"
    echo -e "  ${BLUE}Alt+E${NC}      - Wrap with 'ai create'"
    echo -e "  ${BLUE}Tab${NC}        - Autocomplete files and commands"
fi

# ============================================================================
# BASH COMPLETIONS
# ============================================================================

if [ "$SHELL_TYPE" = "bash" ]; then
    # Define completion function for bash
    _ai_completion_bash() {
        local cur prev words cword
        _init_completion || return
        
        local suggestions=""
        
        # First word completions
        if [ $cword -eq 1 ]; then
            suggestions="what how explain compare create find backup why analyze read show"
            COMPREPLY=($(compgen -W "$suggestions" -- "$cur"))
            return
        fi
        
        # File completions for file-related queries
        if [[ "${words[*]}" =~ (read|show|analyze|compare|what.*do|explain.*file) ]]; then
            COMPREPLY=($(compgen -f -- "$cur"))
            return
        fi
        
        # Default to filename completion
        COMPREPLY=($(compgen -f -- "$cur"))
    }
    
    # Register bash completion
    complete -F _ai_completion_bash ai
    
    echo ""
    echo -e "${CYAN}Bash tab completion enabled${NC}"
fi