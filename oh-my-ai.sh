#!/bin/bash

#!/bin/bash

# AI Shell Assistant - Ollama-powered Bash/Zsh Assistant
# Installation: curl -s https://raw.githubusercontent.com/nirodg/ oh-my-ai/main/install-ai.sh | bash
# Repository: https://github.com/nirodg/ oh-my-ai

# Check if script is being run directly or sourced
# if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
#     echo "🤖 AI Shell Assistant"
#     echo ""
#     echo "This script is designed to be sourced, not executed directly."
#     echo ""
#     echo "To install:"
#     echo "  curl -s https://raw.githubusercontent.com/nirodg/ oh-my-ai/main/install-ai.sh | bash"
#     echo ""
#     echo "Then add to your shell:"
#     echo "  source ~/.local/bin/ai.sh"
#     echo ""
#     exit 1
# fi

# ai.sh - Ollama-powered Bash/Zsh Assistant
# A smart shell assistant that understands your environment and can execute commands safely

# Configuration
OLLAMA_MODEL="${OLLAMA_MODEL:-llama3.2}"
OLLAMA_HOST="${OLLAMA_HOST:-http://localhost:11434}"
HISTORY_LINES=20
WORK_DIR="$(pwd)"  # Lock to the directory where helper was sourced
MAX_FILE_SIZE=100000  # Max file size to read (100KB)
AI_CONFIG_FILE="${HOME}/.ai_sh_config"
OH_MY_AI_DIR="${HOME}/.oh-my-ai"
UPDATE_FILE="${OH_MY_AI_DIR}/last_update_check"
UPDATE_INFO_FILE="${OH_MY_AI_DIR}/update_info"

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

# Auto-update functionality
# Enhanced auto-update functionality
check_for_updates() {
    # Create oh-my-ai directory if it doesn't exist
    mkdir -p "$OH_MY_AI_DIR"
    
    local current_script="$0"
    local repo_url="https://raw.githubusercontent.com/nirodg/oh-my-ai/main/oh-my-ai.sh"
    
    # Only check once per day
    if [ -f "$UPDATE_FILE" ]; then
        local last_check=$(stat -f %m "$UPDATE_FILE" 2>/dev/null || stat -c %Y "$UPDATE_FILE" 2>/dev/null)
        local now=$(date +%s)
        local hours_since_check=$(( (now - last_check) / 3600 ))
        
        if [ $hours_since_check -lt 24 ]; then
            return 0
        fi
    fi
    
    touch "$UPDATE_FILE"
    
    log_info "🔍 Checking for updates..." >&2
    
    # Get current version info
    local current_version=$(stat -f %m "$current_script" 2>/dev/null || stat -c %Y "$current_script" 2>/dev/null)
    local current_hash=$(sha256sum "$current_script" 2>/dev/null | cut -d' ' -f1)
    
    # Download latest version to compare
    local temp_file="/tmp/ai_latest_$$.sh"
    
    if command -v curl > /dev/null 2>&1; then
        if ! curl -s -f -L "$repo_url" -o "$temp_file" 2>/dev/null; then
            rm -f "$temp_file"
            return 1
        fi
    elif command -v wget > /dev/null 2>&1; then
        if ! wget -q "$repo_url" -O "$temp_file" 2>/dev/null; then
            rm -f "$temp_file"
            return 1
        fi
    else
        return 1
    fi
    
    if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
        rm -f "$temp_file"
        return 1
    fi
    
    local latest_hash=$(sha256sum "$temp_file" 2>/dev/null | cut -d' ' -f1)
    
    # Store update info
    cat > "$UPDATE_INFO_FILE" << EOF
# Oh My AI Update Information
LAST_CHECKED=$(date +%Y-%m-%d\ %H:%M:%S)
CURRENT_VERSION=$current_hash
LATEST_VERSION=$latest_hash
UPDATE_AVAILABLE=$([ "$current_hash" != "$latest_hash" ] && echo "true" || echo "false")
EOF
    
    if [ "$current_hash" != "$latest_hash" ] && [ -n "$current_hash" ] && [ -n "$latest_hash" ]; then
        echo -e "${YELLOW}🔄 Update available for Oh My AI!${NC}" >&2
        echo -e "${CYAN}Current: $(date -r "$current_script" 2>/dev/null || echo "unknown")${NC}" >&2
        echo -e "${CYAN}Latest:  $(date -r "$temp_file" 2>/dev/null || echo "unknown")${NC}" >&2
        echo "" >&2
        
        # Ask user if they want to update
        echo -e "${BLUE}Would you like to update now? (Y/n)${NC}" >&2
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]] || [ -z "$response" ]; then
            echo -e "${GREEN}🚀 Starting update...${NC}" >&2
            update_ai
        else
            echo -e "${YELLOW}Update skipped. You can update later with: ai update${NC}" >&2
        fi
        echo "" >&2
    else
        echo -e "${GREEN}✓ Oh My AI is up to date${NC}" >&2
    fi
    
    rm -f "$temp_file"
}

# ============================================================================
# OLLAMA SETUP AND CONNECTIVITY
# ============================================================================

# Load saved configuration
load_config() {
    if [ -f "$AI_CONFIG_FILE" ]; then
        source "$AI_CONFIG_FILE"
    fi
}

if [ -z "$OH_MY_AI_NO_UPDATE" ]; then
    (check_for_updates &) > /dev/null 2>&1
fi

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
        echo -e "${CYAN}Enter Ollama host (format: http://host:port):${NC}"
        read -r custom_host
        
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
    
    if ! command -v docker &> /dev/null; then
        echo -e "${RED}✗ Docker is not installed${NC}"
        echo -e "${YELLOW}Please install Docker from: https://docs.docker.com/get-docker/${NC}"
        return 1
    fi
    
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}✗ Docker daemon is not running${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ Docker is installed and running${NC}"
    echo ""
    
    if docker ps -a --format '{{.Names}}' | grep -q '^ollama$'; then
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
            OLLAMA_HOST="http://localhost:11434"
            export OLLAMA_HOST
            save_config
            return 0
        fi
    fi
    
    echo -e "${YELLOW}Deploy Ollama in Docker container? (Y/n)${NC}"
    read -r response
    
    if [[ "$response" =~ ^[Nn]$ ]]; then
        return 1
    fi
    
    echo ""
    echo -e "${BLUE}🚀 Deploying Ollama container...${NC}"
    
    if docker run -d \
        --name ollama \
        -p 11434:11434 \
        -v ollama:/root/.ollama \
        --restart unless-stopped \
        ollama/ollama; then
        
        echo -e "${GREEN}✓ Ollama container deployed${NC}"
        echo -e "${BLUE}Waiting for Ollama to start...${NC}"
        
        local attempt=0
        while [ $attempt -lt 30 ]; do
            if check_ollama_connectivity "http://localhost:11434"; then
                echo -e "${GREEN}✓ Ollama is ready!${NC}"
                break
            fi
            sleep 2
            attempt=$((attempt + 1))
            echo -n "."
        done
        echo ""
        
        OLLAMA_HOST="http://localhost:11434"
        export OLLAMA_HOST
        save_config
        
        echo -e "${BLUE}📦 Pulling model: $OLLAMA_MODEL${NC}"
        docker exec ollama ollama pull "$OLLAMA_MODEL"
        
        echo -e "${GREEN}✓ Setup complete!${NC}"
        return 0
    fi
    return 1
}

# Main setup function
setup_ollama() {
    load_config
    
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA}🤖 AI.sh Ollama Setup${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
    
    echo -e "${BLUE}Checking for Ollama at $OLLAMA_HOST...${NC}"
    if check_ollama_connectivity "$OLLAMA_HOST"; then
        echo -e "${GREEN}✓ Ollama is running at $OLLAMA_HOST${NC}"
        
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
    
    echo -e "${YELLOW}✗ Ollama is not accessible${NC}"
    echo ""
    
    if ask_custom_host; then
        return 0
    fi
    
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
    echo -e "${YELLOW}Install manually: https://ollama.ai${NC}"
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
    
    context+="Working directory: $WORK_DIR\n"
    context+="Current directory: $(pwd)\n"
    context+="Files: $(ls -1 | head -20 | tr '\n' ' ')\n\n"
    
    context+="Recent commands:\n"
    context+="$(history | tail -n $HISTORY_LINES | cat -n)\n\n"
    
    context+="System: $(uname -s)\n"
    context+="Shell: $SHELL\n"
    context+="User: $USER\n"
    
    if git rev-parse --git-dir > /dev/null 2>&1; then
        context+="Git branch: $(git branch --show-current 2>/dev/null)\n"
        context+="Git status: $(git status -s | head -5)\n"
    fi
    
    echo -e "$context"
}

# Safety check for commands
is_safe_command() {
    local cmd="$1"
    
    local dangerous_patterns=(
        "rm -rf /"
        "dd if="
        "mkfs"
        ":(){:|:&};:"
        "> /dev/sda"
        "mv /* "
        "chmod -R 777 /"
    )
    
    for pattern in "${dangerous_patterns[@]}"; do
        if [[ "$cmd" == *"$pattern"* ]]; then
            echo -e "${RED}⛔ Blocked: Dangerous command${NC}"
            return 1
        fi
    done
    
    if [[ "$cmd" == *"cd /"* ]] || [[ "$cmd" == *"cd ~"* ]]; then
        echo -e "${RED}⛔ Blocked: Cannot leave work directory${NC}"
        return 1
    fi
    
    if [[ "$cmd" == sudo* ]] || [[ "$cmd" == su* ]]; then
        echo -e "${RED}⛔ Blocked: Root privileges not allowed${NC}"
        return 1
    fi
    
    return 0
}

# Execute a command safely within work directory
safe_execute() {
    local cmd="$1"
    local confirm="${2:-yes}"
    
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
    
    (
        cd "$WORK_DIR" || exit 1
        eval "$cmd"
    )
    
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ Command completed${NC}"
    else
        echo -e "${RED}✗ Command failed (exit $exit_code)${NC}"
    fi
    
    return $exit_code
}

# ============================================================================
# OLLAMA API INTERACTION
# ============================================================================

call_ollama() {
    local prompt="$1"
    local stream="${2:-false}"
    
    # Try API first
    local response=$(printf '%s' "$prompt" | curl -s -X POST "$OLLAMA_HOST/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"$OLLAMA_MODEL\", \"prompt\": $(printf '%s' "$prompt" | jq -Rs .), \"stream\": $stream}" \
        2>/dev/null | jq -r '.response' 2>/dev/null)
    
    # Fallback to CLI if API fails
    if [ -z "$response" ] && command -v ollama &> /dev/null; then
        response=$(printf '%s' "$prompt" | ollama run "$OLLAMA_MODEL" 2>/dev/null)
    fi
    
    echo "$response"
}

# ============================================================================
# INTELLIGENT INTENT DETECTION
# ============================================================================

# Extract files mentioned in query
extract_files() {
    local query="$1"
    local files=()
    
    # Split query into words and check each against filesystem
    local words_array=($query)
    for word in "${words_array[@]}"; do
        local cleaned=$(echo "$word" | sed 's/[?,!.]$//' | sed 's/^["\x27]//' | sed 's/["\x27]$//')
        if [ -f "$cleaned" ]; then
            files+=("$cleaned")
        fi
    done
    
    echo "${files[@]}"
}

# Deterministic intent detection (no LLM needed for obvious cases)
detect_intent_deterministic() {
    local query="$1"
    local files="$2"
    local file_count=$(echo "$files" | wc -w)
    
    # Exact command matches
    case "$query" in
        "help"|"--help"|"-h")
            echo "HELP"
            return 0
            ;;
        "update"|"upgrade")
            echo "UPDATE"
            return 0
            ;;
    esac
    
    # File-based detection (deterministic)
    if [ $file_count -ge 2 ]; then
        if [[ "$query" =~ (compare|diff|difference|vs|versus) ]]; then
            echo "COMPARE"
            return 0
        fi
    fi
    
    if [ $file_count -eq 1 ]; then
        if [[ "$query" =~ (what does|what is|show me|read|analyze|explain|open|cat|view).*$(echo $files) ]] || \
           [[ "$query" =~ $(echo $files).*(do|contain|inside|mean) ]]; then
            echo "READFILE"
            return 0
        fi
    fi
    
    # Command execution patterns (deterministic)
    if [[ "$query" =~ ^(create|make|build|generate|write).*(script|file|backup|command) ]]; then
        echo "BUILD"
        return 0
    fi
    
    if [[ "$query" =~ ^(find|search|locate|list).*(file|directory|folder) ]]; then
        echo "BUILD"
        return 0
    fi
    
    # History-based patterns
    if [[ "$query" =~ (explain|what did|what does).*(last|previous|that|the).*command ]]; then
        echo "EXPLAIN"
        return 0
    fi
    
    if [[ "$query" =~ (why|debug|fix|error|failed|wrong) ]] && [[ "$query" =~ (last|previous|that|it) ]]; then
        echo "DEBUG"
        return 0
    fi
    
    if [[ "$query" =~ (what (am i|have i|was i)|my workflow|my activity|what i.*doing) ]]; then
        echo "ANALYZE"
        return 0
    fi
    
    # If no deterministic match, use LLM
    echo "UNKNOWN"
}

# LLM-based intent detection (only when needed)
detect_intent_llm() {
    local query="$1"
    local files="$2"
    local context="$3"
    
    local intent_prompt="You are analyzing a user's shell command request. Respond with ONLY ONE WORD.

User request: $query
Files mentioned: $files
Recent commands: $(history | tail -n 3 | sed 's/^[ ]*[0-9]*[ ]*//')

Choose the SINGLE BEST intent:
- READFILE: Read/analyze a specific file that exists
- COMPARE: Compare 2+ existing files  
- BUILD: Create/execute a NEW shell command
- EXPLAIN: Explain a PREVIOUS command from history
- DEBUG: Debug/fix a FAILED previous command
- ANALYZE: Analyze work history/patterns
- CHAT: General conversation about concepts/questions

Respond with ONLY the intent word (e.g., CHAT, BUILD, etc.)"

    local intent=$(call_ollama "$intent_prompt")
    intent=$(echo "$intent" | tr -d '\n' | tr '[:lower:]' '[:upper:]' | xargs | head -n 1 | awk '{print $1}')
    
    echo "$intent"
}

# ============================================================================
# MAIN AI COMMAND
# ============================================================================

ai() {
    case "$1" in
        "help"|"--help"|"-h")
            ai_help
            return 0
            ;;
        "update"|"upgrade")
            echo -e "${YELLOW}Update functionality not implemented yet${NC}"
            return 0
            ;;
    esac
    
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: ai <your question>${NC}"
        echo ""
        echo "Examples:"
        echo "  ai what does script.sh do?"
        echo "  ai compare old.py and new.py"
        echo "  ai create a backup of all logs"
        echo "  ai why did that fail?"
        return 1
    fi
    
    local query="$*"
    local context=$(gather_context)
    local files=$(extract_files "$query")
    
    echo -e "${BLUE}🤖 Processing...${NC}"
    
    # Try deterministic detection first (fast, accurate for obvious cases)
    local intent=$(detect_intent_deterministic "$query" "$files")
    
    # If uncertain, use LLM (slower but handles ambiguous cases)
    if [ "$intent" = "UNKNOWN" ]; then
        intent=$(detect_intent_llm "$query" "$files" "$context")
    fi
    
    echo -e "${CYAN}→ Detected intent: $intent${NC}"
    
    # Execute based on intent
    case "$intent" in
        READFILE)
            local file_array=($files)
            if [ ${#file_array[@]} -eq 0 ]; then
                echo -e "${RED}✗ No file detected${NC}"
                return 1
            fi
            
            local file="${file_array[0]}"
            echo -e "${CYAN}📖 Reading: $file${NC}\n"
            
            local content=$(read_file "$file")
            if [ $? -ne 0 ]; then
                return 1
            fi
            
            local file_prompt="File: $file

Content:
$content

User question: $query

Analyze this file and answer the user's question. Be concise and practical."
            
            call_ollama "$file_prompt"
            ;;
            
        COMPARE)
            local file_array=($files)
            if [ ${#file_array[@]} -lt 2 ]; then
                echo -e "${RED}✗ Need 2+ files to compare${NC}"
                return 1
            fi
            
            echo -e "${CYAN}📊 Comparing files...${NC}\n"
            
            local file_contents=$(read_files_for_context $files)
            local compare_prompt="$file_contents

User request: $query

Compare these files, highlighting key differences and answering the user's question."
            
            call_ollama "$compare_prompt"
            ;;
            
        BUILD)
            echo -e "${CYAN}🔨 Building command...${NC}\n"
            
            local build_prompt="Context:
$context

User wants: $query

Generate a SINGLE shell command that accomplishes this goal safely.
Respond with ONLY the command, no explanation, no markdown."
            
            local cmd=$(call_ollama "$build_prompt")
            cmd=$(echo "$cmd" | sed 's/```.*//g' | sed 's/^[[:space:]]*//' | head -n 1)
            
            echo -e "${GREEN}Suggested:${NC} $cmd"
            echo ""
            safe_execute "$cmd" "yes"
            ;;
            
        EXPLAIN)
            local last_cmd=$(history | tail -n 2 | head -n 1 | sed 's/^[ ]*[0-9]*[ ]*//')
            
            if [ -z "$last_cmd" ]; then
                echo "No recent command found"
                return 1
            fi
            
            echo -e "${CYAN}📚 Explaining: ${YELLOW}$last_cmd${NC}\n"
            
            local explain_prompt="Context:
$context

Command to explain: $last_cmd

Explain what this command does and why the user might have run it. Be concise."
            
            call_ollama "$explain_prompt"
            ;;
            
        DEBUG)
            local last_cmd=$(history | tail -n 2 | head -n 1 | sed 's/^[ ]*[0-9]*[ ]*//')
            
            echo -e "${CYAN}🔍 Debugging: ${YELLOW}$last_cmd${NC}\n"
            
            local debug_prompt="Context:
$context

Failed command: $last_cmd

Explain why this likely failed and suggest a fix. Be specific and actionable."
            
            call_ollama "$debug_prompt"
            ;;
            
        ANALYZE)
            echo -e "${CYAN}📊 Analyzing activity...${NC}\n"
            
            local analyze_prompt="$context

Request: $query

Analyze the user's recent work and provide insights about their workflow."
            
            call_ollama "$analyze_prompt"
            ;;
            
        *)
            # Default CHAT mode
            if [ -n "$files" ]; then
                local file_context=$(read_files_for_context $files)
                context+="\n\nFiles:\n$file_context"
            fi
            
            echo -e "${CYAN}💬 Chat mode${NC}\n"
            
            local chat_prompt="Context:
$context

User: $query

You are a helpful shell assistant. Answer the question using the context provided. Be practical and concise."
            
            call_ollama "$chat_prompt"
            ;;
    esac
    
    echo -e "\n${GREEN}───────────────────────────────${NC}"
}



# Update command with better feedback
update_ai() {
    echo -e "${BLUE}🚀 Updating Oh My AI...${NC}"
    
    # Create oh-my-ai directory if it doesn't exist
    mkdir -p "$OH_MY_AI_DIR"
    
    # Store update attempt
    cat > "$UPDATE_INFO_FILE" << EOF
# Oh My AI Update Information
LAST_UPDATE_ATTEMPT=$(date +%Y-%m-%d\ %H:%M:%S)
UPDATE_STATUS=in_progress
EOF
    
    local update_success=false
    
    if command -v curl > /dev/null 2>&1; then
        echo -e "${CYAN}Using curl to update...${NC}"
        if curl -s https://raw.githubusercontent.com/nirodg/oh-my-ai/main/install-ai.sh | bash; then
            update_success=true
        fi
    elif command -v wget > /dev/null 2>&1; then
        echo -e "${CYAN}Using wget to update...${NC}"
        if wget -q -O - https://raw.githubusercontent.com/nirodg/oh-my-ai/main/install-ai.sh | bash; then
            update_success=true
        fi
    else
        echo -e "${RED}✗ Neither curl nor wget found${NC}"
    fi
    
    # Update status file
    if [ "$update_success" = true ]; then
        cat > "$UPDATE_INFO_FILE" << EOF
# Oh My AI Update Information
LAST_SUCCESSFUL_UPDATE=$(date +%Y-%m-%d\ %H:%M:%S)
UPDATE_STATUS=success
EOF
        echo -e "${GREEN}✓ Update completed successfully!${NC}"
        echo -e "${CYAN}Please restart your shell or run: source ~/.local/bin/ai.sh${NC}"
    else
        cat > "$UPDATE_INFO_FILE" << EOF
# Oh My AI Update Information
LAST_FAILED_UPDATE=$(date +%Y-%m-%d\ %H:%M:%S)
UPDATE_STATUS=failed
EOF
        echo -e "${RED}✗ Update failed${NC}"
        echo -e "${YELLOW}You can try manual installation:${NC}"
        echo "  curl -s https://raw.githubusercontent.com/nirodg/oh-my-ai/main/install-ai.sh | bash"
    fi
}

# Show update information
show_update_info() {
    echo -e "${CYAN}🤖 Oh My AI - Version Information${NC}"
    echo ""
    
    # Current script info
    local current_script="$0"
    echo -e "${BLUE}Current Installation:${NC}"
    echo -e "  Path: $current_script"
    echo -e "  Modified: $(date -r "$current_script" 2>/dev/null || echo "unknown")"
    echo -e "  Hash: $(sha256sum "$current_script" 2>/dev/null | cut -d' ' -f1 | head -c 16)..."
    echo ""
    
    # Update info from file
    if [ -f "$UPDATE_INFO_FILE" ]; then
        echo -e "${BLUE}Update Information:${NC}"
        while IFS='=' read -r key value; do
            if [[ ! $key =~ ^# ]] && [ -n "$key" ]; then
                echo -e "  ${key}: $value"
            fi
        done < "$UPDATE_INFO_FILE"
    else
        echo -e "${YELLOW}No update information available${NC}"
        echo -e "  Run 'ai update' to check for updates"
    fi
}

# Main AI helper function with intelligent routing


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


# ============================================================================
# INITIALIZATION
# ============================================================================

if ! check_ollama; then
    if ! setup_ollama; then
        echo -e "${RED}✗ AI assistant requires Ollama${NC}"
        return 1
    fi
    echo ""
fi

if check_ollama; then
    echo -e "${GREEN}✓ oh-my-ai loaded! (${SHELL_TYPE})${NC}"
    echo -e "${BLUE}Directory:${NC} $WORK_DIR"
    echo -e "${BLUE}Ollama:${NC} $OLLAMA_HOST"
    echo -e "${BLUE}Model:${NC} $OLLAMA_MODEL"
    echo ""
    echo -e "${CYAN}Type: ${BLUE}ai <anything>${NC}"
    echo -e "${CYAN}Help: ${BLUE}ai help${NC}"
    
    if [ "$SHELL_TYPE" = "zsh" ]; then
        echo -e "${GREEN}✓ Zsh features enabled${NC}"
    fi
fi


# ============================================================================
# ZSH COMPLETIONS AND KEYBINDINGS
# ============================================================================

if [ "$SHELL_TYPE" = "zsh" ]; then
    autoload -Uz compinit
    compinit 2>/dev/null
    
    _ai_completion() {
        local current="${words[CURRENT]}"
        local -a completions
        
        if [[ $CURRENT -gt 1 ]]; then
            local -a files
            files=($(ls -1 2>/dev/null))
            completions+=("${files[@]}")
            
            if [ ${#words[@]} -eq 2 ]; then
                completions+=(
                    "what" "how" "explain" "compare" 
                    "create" "find" "why" "analyze"
                )
            fi
            
            compadd -a completions
        fi
    }
    
    compdef _ai_completion ai
    
    # Keybindings
    ai_help_widget() {
        BUFFER=""
        zle push-line
        ai_help
        zle reset-prompt
    }
    zle -N ai_help_widget
    bindkey '^[h' ai_help_widget
    
    ai_explain_widget() {
        if [ -n "$BUFFER" ]; then
            BUFFER="ai explain $BUFFER"
            CURSOR=${#BUFFER}
        fi
        zle reset-prompt
    }
    zle -N ai_explain_widget
    bindkey '^[a' ai_explain_widget
    
    ai_create_widget() {
        if [ -n "$BUFFER" ] && [[ ! "$BUFFER" =~ ^ai ]]; then
            BUFFER="ai create $BUFFER"
            CURSOR=${#BUFFER}
        fi
        zle reset-prompt
    }
    zle -N ai_create_widget
    bindkey '^[e' ai_create_widget
fi

# Bash completions
if [ "$SHELL_TYPE" = "bash" ]; then
    _ai_completion_bash() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local words="what how explain compare create find why analyze help"
        COMPREPLY=($(compgen -W "$words" -f -- "$cur"))
    }
    complete -F _ai_completion_bash ai
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