
# 🤖 Oh My AI - Your Intelligent Shell Assistant

<div align="center">

![AI Assistant](https://img.shields.io/badge/AI-Powered-blue?style=for-the-badge&logo=ai)
![Shell](https://img.shields.io/badge/Shell-Bash%2FZsh-green?style=for-the-badge&logo=gnu-bash)
![Ollama](https://img.shields.io/badge/Powered%20by-Ollama-orange?style=for-the-badge)

**Transform your terminal into an AI-powered workspace!**  
*Understand your environment, analyze files, debug commands, and get intelligent assistance right in your shell.*

[Features](#-features) • [Installation](#-installation) • [Usage](#-usage) • [Download](#-download)

</div>

## 🚀 What Does Oh My AI Do?

Oh My AI is a **smart shell assistant** that integrates directly with your terminal to provide context-aware AI assistance. Here's what it actually does:

### 🎯 Core Functionality

**🧠 Intelligent Command Assistance**
- Ask natural language questions about your code and files
- Get explanations for previous commands
- Debug failed commands with context-aware analysis
- Receive safe command suggestions for common tasks

**📁 File & Code Analysis** 
- Read and analyze any file in your current workspace
- Compare multiple files and highlight differences
- Understand what scripts and configuration files do
- Get code explanations and summaries

**🔍 Context Awareness**
- Automatically reads your command history for context
- Understands your current directory and files
- Detects git repositories and provides git context
- Knows your system environment and shell type

**🛡️ Safety First**
- All commands are validated for safety before execution
- Prevents dangerous operations like `rm -rf /`
- Locks execution to your current workspace directory
- Requires confirmation before executing suggested commands

## 📥 Download & Install

### Option 1: One-Line Auto Install (Recommended)
```bash
curl -s https://raw.githubusercontent.com/nirodg/oh-my-ai/main/install-ai.sh | bash
```

### Option 2: Direct Download & Manual Install
```bash
# Download the main script
curl -s -L https://raw.githubusercontent.com/nirodg/oh-my-ai/main/oh-my-ai.sh -o ~/.local/bin/ai.sh

# Make it executable
chmod +x ~/.local/bin/ai.sh

# Add to your shell (choose one)
echo "source ~/.local/bin/ai.sh" >> ~/.bashrc    # For bash
echo "source ~/.local/bin/ai.sh" >> ~/.zshrc     # For zsh

# Reload your shell
source ~/.bashrc   # or source ~/.zshrc
```

### Option 3: Download Individual Files
- **Main Script** - The core AI assistant  
- **Installer** - Automated installation script

---

## ⚙️ Prerequisites

### Required: Ollama
Oh My AI requires Ollama to be installed and running:

```bash
curl -fsSL https://ollama.ai/install.sh | sh
ollama serve
ollama pull llama3.2
```

---

## 🎮 How to Use

### Basic Usage
```bash
ai <your question or request>
```

### Real Examples

### Two-Tier Intent Detection
#### 1. Deterministic Detection (Fast & Accurate)
Uses pattern matching for obvious cases - no LLM needed:
```
# File operations (100% accurate)
ai what does script.sh do?          → READFILE (file exists in query)
ai compare old.py new.py            → COMPARE (2+ files + "compare")
ai show me config.json              → READFILE (file + "show me")

# Command building (keyword-based)
ai create a backup script           → BUILD (starts with "create")
ai find all .log files              → BUILD (starts with "find")

# History operations (pattern-based)
ai explain the last command         → EXPLAIN ("explain" + "last command")
ai why did that fail?               → DEBUG ("why" + "that")

# Workflow analysis
ai what have I been working on?     → ANALYZE ("what have i been")
```
#### 2. LLM Detection (Only When Needed)
For ambiguous queries, uses Ollama:
```
ai help me with this error          → LLM decides (DEBUG vs CHAT)
ai can you check something?         → LLM decides intent
ai script.sh issues                 → LLM decides (READFILE vs DEBUG)
```
##### 🔍 Smart File Detection
Automatically finds files in queries
```
ai what does delete.me do?          → Finds "delete.me" exists
ai compare "config old.txt" new.cfg → Handles spaces/quotes
ai show me script.sh and test.py    → Extracts both files
```
###✅ Flawless Command Flow
Intent → Action Mapping

1. **READFILE** → Read file, ask AI to analyze it
2. **COMPARE** → Read multiple files, ask AI to compare
3. **BUILD** → Generate command, confirm, execute safely
4. **EXPLAIN** → Get last command from history, explain it
5. **DEBUG** → Get failed command, diagnose issue
6. **ANALYZE** → Analyze command history patterns
7. **CHAT** → General conversation with context

#### Safety Guarantees
```
# All BUILD commands require confirmation
ai create a backup
🔨 Building command...
Suggested: tar -czf backup.tar.gz *
Confirm? (y/N): 

# Dangerous commands are blocked
Blocked patterns: rm -rf /, dd if=, mkfs, fork bombs, etc.
Blocked operations: cd /, sudo, su
All operations locked to $WORK_DIR
```

###🎨 User Experience
####Clear Feedback
```
🤖 ➜ ai what does script.sh do
🤖 Processing...
→ Detected intent: READFILE
📖 Reading: script.sh

[AI analyzes file...]
```
#### Transparent Intent
```
🤖 ➜ ai create backup script
🤖 Processing...
→ Detected intent: BUILD
🔨 Building command...

Suggested: tar -czf backup_$(date +%Y%m%d).tar.gz *.txt
Execute? (y/N):
```


####🚀 Performance
- **Fast**: Deterministic detection = instant (no LLM call)
- **Accurate**: Pattern matching catches 80% of cases correctly
- **Smart**: LLM handles ambiguous cases perfectly
- **Efficient**: Only one LLM call per command (not multiple)

#### Test cases
```
# File operations
ai what does script.sh do?          ✓ READFILE
ai show me config.json              ✓ READFILE  
ai analyze delete.me                ✓ READFILE
ai compare old.py new.py            ✓ COMPARE

# Command building
ai create a backup                  ✓ BUILD
ai find large files                 ✓ BUILD
ai make a script to compress logs   ✓ BUILD

# History operations  
ai explain the last command         ✓ EXPLAIN
ai what did that do?                ✓ EXPLAIN
ai why did that fail?               ✓ DEBUG
ai fix the error                    ✓ DEBUG

# Workflow
ai what have I been working on?     ✓ ANALYZE
ai my recent activity               ✓ ANALYZE

# Chat
ai how do pipes work?               ✓ CHAT
ai explain grep                     ✓ CHAT
```

---

## ✨ Key Features
### 🔍 Smart Intent Detection
- Detects filenames  
- Understands command-building  
- Automatically enters debug mode when needed  
- Explains commands with natural language

### 🎨 Enhanced Zsh Experience
- Tab completion  
- Smart AI suggestions  
- Colorful prompts  

### 🔒 Built-in Safety
- Validates commands  
- Prevents directory escape  
- Blocks dangerous patterns  
- Asks for confirmation  
- Checks file sizes  

### 🐳 Docker Support
If you don't have Ollama installed, it can deploy via Docker automatically.

---

## 🛠️ Configuration

### Environment Variables
```bash
export OLLAMA_MODEL="llama3.2"
export OLLAMA_HOST="http://localhost:11434"
```

### Persistent Config (`~/.ai_sh_config`)
```bash
export OLLAMA_HOST="http://localhost:11434"
export OLLAMA_MODEL="llama3.2"
```

---

## ❓ Troubleshooting

### "Ollama not found"
```bash
curl -fsSL https://ollama.ai/install.sh | sh
```

### "Command not found"
```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### "Permission denied"
```bash
chmod +x ~/.local/bin/ai.sh
```

---

## 📁 Project Structure
```
oh-my-ai/
├── oh-my-ai.sh
├── install-ai.sh
└── README.md
```

---

## 👨‍💻 Developer

**Brage Dorin**  
GitHub: @nirodg  
Repository: https://github.com/nirodg/oh-my-ai

---

## 📄 License

MIT License - see LICENSE file.

<div align="center">

Ready to supercharge your terminal? 🚀  
⬆ Back to Top

</div>

## 📥 Direct Download Links
- Download Main Script  
- Download Installer

```bash
wget https://raw.githubusercontent.com/nirodg/oh-my-ai/main/oh-my-ai.sh
curl -O https://raw.githubusercontent.com/nirodg/oh-my-ai/main/oh-my-ai.sh
```
