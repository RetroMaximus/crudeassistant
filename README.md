Local LLM + LSP Assistant for Linux Mint

This project provides a collection of shell scripts to set up and manage a local Large Language Model (LLM) server using Ollama, along with editor integrations (Neovim and VS Code) for AI‑assisted coding. It is specifically designed for older hardware with limited resources (GTX 960M, 10 GB RAM) and includes features for both host (server) and client machines on the same network.
Overview

The scripts automate the installation and configuration of:

    Ollama – A lightweight, local LLM server.

    Coding‑optimized models – deepseek-coder, qwen2.5-coder, phi3, tinyllama, codellama, mistral (all quantised to fit your GPU/RAM).

    Neovim integration via llm.nvim or gen.nvim with pre‑configured keymaps.

    VS Code integration via the Continue extension.

    Firewall management to allow secure remote access on your home network.

    IP address masking for privacy when displaying the server’s address.

    Custom model creation with different system prompts and parameters.

All scripts are written in Bash and are intended to be run on Linux Mint (or similar Debian‑based distributions), but many also work on macOS and Windows (via MSYS2) with slight modifications.
Prerequisites

    Operating System: Linux Mint (20.x / 21.x) recommended; others may work with adjustments.

    Hardware:

        NVIDIA GTX 960M (2 GB VRAM) or similar.

        At least 10 GB RAM.

    Software:

        curl, wget, git, build-essential (installed automatically if missing).

        NVIDIA drivers (optional but recommended for GPU acceleration).

        Python 3 (optional, used for advanced response parsing).

        jq (optional, used for JSON parsing if Python is unavailable).

Installation

    Clone or download all scripts into a directory (e.g., ~/llm-assistant).

    Make them executable:
    bash

    chmod +x *.sh

    Run the main setup script:
    bash

    ./setup-llm-lsp.sh

    The script will:

        Update your system and install dependencies.

        Check for NVIDIA drivers (optional).

        Install Ollama (if not already present) and start the service.

        Prompt you to choose a model (deepseek‑coder:1.3b is the default and recommended).

        Offer to set up Neovim integration (with plugin selection) and/or VS Code.

        Create a helper script ask-llm.sh for easy querying.

        If you choose client mode during setup, you will be asked for the target server IP and port.

Included Scripts
Script	Purpose
setup-llm-lsp.sh	Main installation script (run once).
ask-llm.sh	Query the LLM, manage configuration, switch host/client mode.
assign-target-ip-port.sh	Set or change the remote server IP and port.
toggle-target-mask.sh	Toggle masking of the target IP in console output.
restart-ollama.sh	Restart the Ollama service (useful after model changes).
free-mem-restart.sh	Clear system cache and restart Ollama (helpful for low‑memory situations).
start-ai.sh	Start Ollama and configure firewall rules for network access.
stop-ai.sh	Stop Ollama and remove firewall rules.
manage-model-rules.sh	Interactive tool to create, edit, and delete custom Ollama models with different system prompts and parameters.
Configuration
Host vs. Client

    Host machine: Runs the Ollama server and stores models.

    Client machine: Sends queries to the host over the network.

During setup you choose the mode. You can later switch with:
bash

./ask-llm.sh host          # use local Ollama
./ask-llm.sh client        # use remote server (must be configured)

Setting the Target (for clients)

Use the config command inside ask-llm.sh or run assign-target-ip-port.sh directly:
bash

./ask-llm.sh config set 192.168.1.12:11434
# or
./assign-target-ip-port.sh 192.168.1.12 11434

IP Masking

For privacy, the target IP address can be masked in console output (e.g., 192.168.1.XXX). Toggle masking with:
bash

./ask-llm.sh config mask on
./ask-llm.sh config mask off
# or
./toggle-target-mask.sh on

Firewall

When running as a host, the start-ai.sh script automatically adds a UFW rule to allow incoming connections from your local network on port 11434. The stop-ai.sh script removes this rule.
Usage Examples
Ask a Question (default model)
bash

./ask-llm.sh "Write a Python function to compute fibonacci"

Use a Specific Model Alias
bash

./ask-llm.sh ds "Explain recursion"          # deepseek-coder:1.3b
./ask-llm.sh qwen "Write a bash script"      # qwen2.5-coder:1.5b
./ask-llm.sh phi "Generate a unit test"      # phi3:mini
./ask-llm.sh cl "Optimize this SQL query"    # codellama:7b

Pipe Input
bash

echo "How do I sort a list in Python?" | ./ask-llm.sh

Manage Models
bash

./ask-llm.sh models          # list installed models
./ask-llm.sh ps               # show currently loaded models
./ask-llm.sh pull codellama:7b   # download a new model

Free Memory (on host)
bash

./ask-llm.sh free-mem
# or directly
./free-mem-restart.sh

Create a Custom Model
bash

./manage-model-rules.sh
# Follow the interactive menu to set system prompts, parameters, etc.

Editor Integrations
Neovim

If you chose Neovim setup during installation, your ~/.config/nvim/init.lua will be configured with your selected plugin (llm.nvim or gen.nvim).

    llm.nvim keymaps (leader is space):

        <leader>le – Explain selected code

        <leader>lg – Generate code based on prompt

        <leader>lo – Optimize code

        <leader>lt – Generate tests

    gen.nvim keymaps:

        <leader>gg – Open generation prompt

        <leader>ge – Enhance selected code

        <leader>gt – Generate tests

To change the model used by the plugin, edit the init.lua file.
VS Code

If you chose VS Code, the Continue extension will be installed with a configuration pointing to your local Ollama. You can start using it by opening VS Code and invoking Continue: Toggle Full Screen from the command palette.
Security Notes

    The firewall rules added by start-ai.sh allow connections only from your local network (e.g., 192.168.1.0/24). Adjust the network range if needed.

    The target IP and port are stored in ~/.config/llm-target/target.conf with permissions 600 (read/write only for the owner).

    IP masking is applied to console output, but the actual IP remains in the configuration file.

Troubleshooting
No Response or Empty Output

    Ensure Ollama is running: sudo systemctl status ollama

    Check connectivity with ./ask-llm.sh config test

    Verify that the model is pulled: ollama list

Firewall Issues

    On the host, run sudo ufw status to check if port 11434 is allowed.

    Temporarily disable the firewall for testing: sudo ufw disable (re‑enable afterwards).

Memory or Performance Problems

    Use smaller models (deepseek‑coder:1.3b, tinyllama).

    Run ./free-mem-restart.sh to clear caches.

    Consider limiting the number of loaded models in the Ollama service override (see restart-ollama.sh).

Windows / MSYS2 Quirks

    If you use Windows with MSYS2, some commands like ip may not work. The scripts include fallbacks.

    Use the pipe method to avoid command‑line argument mangling:
    bash

    echo "your prompt" | ./ask-llm.sh

Neovim Plugin Errors

    If you see Lua errors related to completion_result, disable autocomplete in the plugin config (the setup script already does this for llm.nvim).

Contributing

Feel free to adapt these scripts to your own needs. They are provided as‑is, but we hope they serve as a useful starting point for your local AI assistant journey.
