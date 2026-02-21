#!/bin/bash

# -----------------------------------------------------------------------------
# Setup script for local LLM + LSP on Linux Mint (GTX 960M, 10GB RAM)
# Includes Neovim LSP integration
# -----------------------------------------------------------------------------

set -e  # Exit on error

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# -----------------------------------------------------------------------------
# Welcome and hardware reminder
# -----------------------------------------------------------------------------
clear
cat << "EOF"
   ___      _ _    _ _             _       _       
  / _ \    | | |  | | |           | |     | |      
 / /_\ \___| | |  | | |_ __   ___ | | __ _| |_ ___ 
 |  _  / _ \ | |/\| | | '_ \ / _ \| |/ _` | __/ _ \
 | | | |  __/ \  /\  / | | | | (_) | | (_| | ||  __/
 \_| |_/\___|_|\/  \_/|_|_| |_|\___/|_|\__,_|\__\___|
                                                     
EOF
echo -e "${GREEN}Welcome to the LLM + LSP installer for Linux Mint!${NC}"
echo ""
print_warn "Your hardware: GTX 960M (2 GB VRAM) + 10 GB RAM"
print_warn "We will install lightweight coding models to fit these constraints."
echo ""
echo "How do you want to set up this machine?"
echo "  1) Host - Run LLM server locally (with Ollama)"
echo "  2) Client - Connect to a remote LLM server"
echo "  3) Abort setup"
echo ""
read -p "Choose [1-3]: " setup_choice

case $setup_choice in
    1)
        AS_CLIENT=false
        print_info "Setting up as HOST machine"
        ;;
    2)
        AS_CLIENT=true
        print_info "Setting up as CLIENT machine"
        
        # Check if target config exists
        if [ -f ~/.config/llm-target/target.conf ]; then
            print_info "Found existing target configuration"
            source ~/.config/llm-target/target.conf
            echo "  Current target: $TARGET_IP_MASKED:$TARGET_PORT_MASKED"
            read -p "Use existing configuration? (y/n): " use_existing
            if [[ ! $use_existing =~ ^[Yy]$ ]]; then
                # Run target assignment script
                if [ -f ~/assign-target-ip-port.sh ]; then
                    ~/assign-target-ip-port.sh
                else
                    read -p "Enter target IP: " TARGET_IP
                    read -p "Enter target port [11434]: " TARGET_PORT
                    TARGET_PORT=${TARGET_PORT:-11434}
                    # Save masked values
                    save_target_config "$TARGET_IP" "$TARGET_PORT"
                fi
            fi
        else
            # Run target assignment script
            if [ -f ~/assign-target-ip-port.sh ]; then
                ~/assign-target-ip-port.sh
            else
                read -p "Enter target IP: " TARGET_IP
                read -p "Enter target port [11434]: " TARGET_PORT
                TARGET_PORT=${TARGET_PORT:-11434}
                # Save masked values
                save_target_config "$TARGET_IP" "$TARGET_PORT"
            fi
        fi
        ;;
    3)
        print_info "Setup aborted"
        exit 0
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

# Function to save target config with masking
save_target_config() {
    local ip="$1"
    local port="$2"
    local config_dir="$HOME/.config/llm-target"
    local config_file="$config_dir/target.conf"
    
    mkdir -p "$config_dir"
    
    # Create masked version (first 3 octets masked for IP, all but last digit for port)
    local ip_masked
    if [[ "$ip" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        ip_masked="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}.XXX"
    else
        ip_masked="XXX.XXX.XXX.XXX"
    fi
    
    local port_masked
    if [ ${#port} -gt 1 ]; then
        port_masked="${port:0:1}$(printf '%*s' $((${#port}-1)) | tr ' ' 'X')"
    else
        port_masked="X"
    fi
    
    cat > "$config_file" << EOF
# LLM Target Configuration
# Created: $(date)
# WARNING: This file contains sensitive information

TARGET_IP="$ip"
TARGET_PORT="$port"
TARGET_IP_MASKED="$ip_masked"
TARGET_PORT_MASKED="$port_masked"
EOF
    
    chmod 600 "$config_file"
    print_info "Target configuration saved securely"
}

# -----------------------------------------------------------------------------
# Update system and install dependencies
# -----------------------------------------------------------------------------
print_step "Updating package list and installing basic dependencies..."
sudo apt update
sudo apt install -y curl wget git build-essential

# -----------------------------------------------------------------------------
# NVIDIA driver check (optional but recommended for GPU acceleration)
# -----------------------------------------------------------------------------
if ! command -v nvidia-smi &> /dev/null; then
    print_warn "NVIDIA drivers are not installed or not loaded."
    read -p "Would you like to install the recommended NVIDIA driver? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Installing NVIDIA driver (this may take a while)..."
        sudo ubuntu-drivers autoinstall
        print_warn "A reboot will be required after installation. Please reboot and run this script again."
        exit 0
    else
        print_warn "Skipping NVIDIA driver installation. The LLM will run on CPU only (slower)."
    fi
else
    print_info "NVIDIA driver detected. GPU acceleration should work."
fi

# -----------------------------------------------------------------------------
# Install Ollama (if not already installed)
# -----------------------------------------------------------------------------
print_step "Checking for Ollama..."

if command -v ollama &> /dev/null; then
    print_info "✓ Ollama is already installed"
    
    # Check if Ollama service is running
    if systemctl is-active --quiet ollama 2>/dev/null; then
        print_info "✓ Ollama service is running"
    else
        print_warn "Ollama service is not running. Starting it now..."
        sudo systemctl start ollama
        sleep 3
        if systemctl is-active --quiet ollama 2>/dev/null; then
            print_info "✓ Ollama service started successfully"
        else
            print_error "Failed to start Ollama service"
        fi
    fi
else
    print_info "Ollama not found. Installing..."
    curl -fsSL https://ollama.com/install.sh | sh
    
    # Check if installation was successful
    if command -v ollama &> /dev/null; then
        print_info "✓ Ollama installed successfully"
        
        # Start the service
        print_info "Starting Ollama service..."
        sudo systemctl start ollama
        sleep 3
    else
        print_error "Ollama installation failed"
        exit 1
    fi
fi

# Wait a moment for the Ollama service to be ready
sleep 2

# -----------------------------------------------------------------------------
# Choose and pull a model
# -----------------------------------------------------------------------------
echo ""
print_info "Available lightweight models for coding:"
echo "  1) deepseek-coder:1.3b (1.3B, coding specialised) [default]"
echo "  2) qwen2.5-coder:1.5b  (1.5B, good for autocomplete)"
echo "  3) phi3:mini           (3.8B, more capable but heavier)"
echo "  4) tinyllama           (1.1B, very fast)"
echo "  5) codellama:7b        (7B, more capable - check VRAM)"
echo "  6) mistral:7b          (7B, general purpose)"
echo ""
read -p "Select model [1-6, default=1]: " model_choice

case $model_choice in
    2) MODEL="qwen2.5-coder:1.5b" ;;
    3) MODEL="phi3:mini" ;;
    4) MODEL="tinyllama" ;;
    5) MODEL="codellama:7b" ;;
    6) MODEL="mistral:7b" ;;
    *) MODEL="deepseek-coder:1.3b" ;;
esac

print_info "Pulling model '$MODEL' (this may take a few minutes depending on your internet)..."
ollama pull "$MODEL"

print_info "✓ Model pulled successfully. Test it with: ollama run $MODEL"

# -----------------------------------------------------------------------------
# Neovim LSP Setup
# -----------------------------------------------------------------------------
echo ""
print_step "Neovim LSP Integration"

read -p "Do you want to set up Neovim with LLM integration? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    
    # Check if Neovim is installed
    if ! command -v nvim &> /dev/null; then
        print_info "Installing Neovim..."
        sudo apt install -y neovim
    else
        print_info "✓ Neovim is already installed"
    fi
    
    # Create Neovim config directory
    mkdir -p ~/.config/nvim
    
    # Install lazy.nvim if not present
    LAZY_PATH="${XDG_DATA_HOME:-$HOME/.local/share}/nvim/lazy/lazy.nvim"
    if [ ! -f "$LAZY_PATH" ]; then
        print_info "Installing lazy.nvim..."
        git clone --filter=blob:none https://github.com/folke/lazy.nvim.git --branch=stable "$LAZY_PATH" 2>/dev/null || true
    else
        print_info "✓ lazy.nvim is already installed"
    fi
    
    # Choose plugin
    echo ""
    echo "Choose Neovim LLM plugin:"
    echo "  1) llm.nvim (Ollama integration) [recommended]"
    echo "  2) gen.nvim (Code generation)"
    echo "  3) Skip plugin installation (manual setup)"
    echo ""
    read -p "Select plugin [1-3, default=1]: " plugin_choice
    
    # Backup existing init.lua if it exists
    if [ -f ~/.config/nvim/init.lua ]; then
        cp ~/.config/nvim/init.lua ~/.config/nvim/init.lua.backup
        print_info "Backed up existing init.lua to init.lua.backup"
    fi
    
    # Create init.lua based on choice
    case $plugin_choice in
        2)
            # gen.nvim setup
            cat > ~/.config/nvim/init.lua << 'EOF'
-- gen.nvim setup
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  {
    "David-Kunz/gen.nvim",
    config = function()
      require("gen").setup({
        model = "deepseek-coder:1.3b",
        host = "localhost",
        port = 11434,
        display_mode = "float",
        show_prompt = true,
        show_model = true,
        no_auto_close = false,
      })
    end,
  },
})

-- Keymaps
vim.keymap.set({ "n", "v" }, "<leader>gg", ":Gen<CR>", { desc = "Generate code" })
vim.keymap.set("v", "<leader>ge", ":Gen Enhance_Code<CR>", { desc = "Enhance code" })
vim.keymap.set("v", "<leader>gt", ":Gen Generate_Test<CR>", { desc = "Generate tests" })
EOF
            print_info "✓ gen.nvim configured"
            ;;
            
        3)
            print_info "Skipping plugin installation. You can manually configure later."
            rm -f ~/.config/nvim/init.lua
            ;;
            
        *)
            # Default: llm.nvim setup
            cat > ~/.config/nvim/init.lua << 'EOF'
-- llm.nvim setup
vim.g.mapleader = " "
vim.g.maplocalleader = " "

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
{
"huggingface/llm.nvim",
dependencies = {
"nvim-lua/plenary.nvim",
"MunifTanjim/nui.nvim",
},
config = function()
require("llm").setup({
backend = "ollama",
model = "deepseek-coder:1.3b",
url = "http://localhost:11434",
temperature = 0.1,
max_tokens = 2048,
-- Disable autocomplete to fix tab error
completion = {
enable = false,
},
suggestion = {
enable = true,
},
})
end,
},
})



-- Keymaps
vim.keymap.set({ "n", "v" }, "<leader>le", ":LlmExplain<CR>", { desc = "Explain code" })
vim.keymap.set({ "n", "v" }, "<leader>lg", ":LlmGenerate<CR>", { desc = "Generate code" })
vim.keymap.set({ "n", "v" }, "<leader>lo", ":LlmOptimize<CR>", { desc = "Optimize code" })
vim.keymap.set({ "n", "v" }, "<leader>lt", ":LlmTest<CR>", { desc = "Generate tests" })
EOF
            print_info "✓ llm.nvim configured"
            ;;
    esac
    
    if [ "$plugin_choice" != "3" ]; then
        # Install plugins (headless mode)
        print_info "Installing plugins (this may take a moment)..."
        nvim --headless -c 'Lazy! sync' -c 'qa' 2>/dev/null || true
        
        print_info "✓ Neovim plugins installed"
        
# Create a basic README
cat > ~/.config/nvim/README.md << EOF
# Neovim LLM Configuration

## Keymaps
- <leader>le - Explain code
- <leader>lg - Generate code  
- <leader>lo - Optimize code
- <leader>lt - Generate tests

## Commands
- :LlmExplain - Explain current selection
- :LlmGenerate - Generate code based on prompt
- :Gen - Open generation prompt (if using gen.nvim)

## Configuration
Model: $MODEL
Endpoint: http://localhost:11434

Note: <leader> is space bar by default
EOF

print_info "✓ Neovim configuration complete!"
echo ""
echo "Neovim setup summary:"
echo "  - Config location: ~/.config/nvim/init.lua"
echo "  - Model: $MODEL"
echo "  - Ollama endpoint: http://localhost:11434"
echo "  - Leader key: Space"
echo ""
echo "To use:"
echo "  1. Open Neovim: nvim"
echo "  2. Select some code in visual mode"
echo "  3. Press Space+le to explain, Space+lg to generate"
fi
fi

# -----------------------------------------------------------------------------
# Optional: Install VS Code and Continue extension
# -----------------------------------------------------------------------------
echo ""
read -p "Do you want to install VS Code and the Continue extension? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Check if code command already exists
    if ! command -v code &> /dev/null; then
        print_info "Installing VS Code..."
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        sudo sh -c 'echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
        rm -f packages.microsoft.gpg
        sudo apt update
        sudo apt install -y code
    else
        print_info "✓ VS Code is already installed"
    fi

    # Install Continue extension
    print_info "Installing Continue extension..."
    code --install-extension continue.continue

    # Create Continue config
    CONFIG_DIR="$HOME/.continue"
    CONFIG_FILE="$CONFIG_DIR/config.json"
    mkdir -p "$CONFIG_DIR"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        cat > "$CONFIG_FILE" <<EOF
{
  "models": [
    {
      "title": "Ollama",
      "provider": "ollama",
      "model": "$MODEL"
    }
  ],
  "tabAutocompleteModel": {
    "title": "Ollama (Autocomplete)",
    "provider": "ollama",
    "model": "$MODEL"
  },
  "experimental": {
    "modelRoles": {
      "chat": "Ollama",
      "edit": "Ollama"
    }
  }
}
EOF
        print_info "✓ Continue configuration created"
    else
        print_warn "Continue config already exists. Please manually add Ollama configuration if needed."
    fi

    print_info "✓ VS Code setup complete"
fi


# -----------------------------------------------------------------------------
# Final instructions
# -----------------------------------------------------------------------------
echo ""
print_info "✅ Setup complete!"
echo ""
echo "What's next:"
echo "  - Ollama is running with model: $MODEL"
echo "  - Try a chat:   ollama run $MODEL"
echo "  - Use helper:   ~/ask-llm.sh \"Your question\""
echo "  - Use with model: ~/ask-llm.sh ds \"Your question\""
echo ""
echo "Neovim users:"
echo "  - Config: ~/.config/nvim/init.lua"
echo "  - Keymaps: <leader>le (explain), <leader>lg (generate)"
echo ""
echo "VS Code users:"
echo "  - Open VS Code and use Continue (Ctrl+Shift+P → Continue: Toggle)"
echo ""
echo "For remote access from other computers:"
echo "  - Edit ~/ask-llm.sh and set AS_CLIENT=true with correct TARGET_IP"
echo ""
echo "Enjoy your local AI assistant!"
