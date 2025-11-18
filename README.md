
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

#### 📖 File Analysis
```bash
ai what does this script do?
ai explain config.json
ai readfile deploy.sh and summarize
```

#### 🐛 Debugging & Explanation
```bash
ai why did the last command fail?
ai explain what "docker-compose up" does
ai debug the previous error
```

#### 🛠️ Command Assistance
```bash
ai how to find all log files?
ai create a backup script
ai suggest a command to clean temp files
```

#### 📊 File Comparison
```bash
ai compare settings_old.py settings_new.py
ai what's different between these configs?
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
