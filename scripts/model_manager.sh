#!/bin/bash

# AI Assistant Model Manager
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/models.json"
MODELS_DIR="$SCRIPT_DIR/../models"

# Load configuration
get_config() {
    jq -r "$1" "$CONFIG_FILE"
}

set_config() {
    jq "$1" "$CONFIG_FILE" > "$CONFIG_FILE.tmp" && mv "$CONFIG_FILE.tmp" "$CONFIG_FILE"
}

# Install a specific model
install_model() {
    local model_key=$1
    local model_name=$(get_config ".available_models.\"$model_key\".name")
    
    if [ -z "$model_name" ] || [ "$model_name" = "null" ]; then
        echo "❌ Model '$model_key' not found in configuration"
        return 1
    fi
    
    echo "📥 Installing model: $model_name"
    ollama pull "$model_name"
    
    # Mark as installed
    set_config ".available_models.\"$model_key\".installed = true"
    echo "✅ Model '$model_name' installed successfully"
}

# Install all models
install_all_models() {
    echo "📥 Installing all configured models..."
    
    get_config '.available_models | keys[]' | while read -r model_key; do
        install_model "$model_key"
    done
}

# Switch active model
switch_model() {
    local model_key=$1
    
    # Check if model exists
    local model_name=$(get_config ".available_models.\"$model_key\".name")
    if [ -z "$model_name" ] || [ "$model_name" = "null" ]; then
        echo "❌ Model '$model_key' not found"
        return 1
    fi
    
    # Check if model is installed
    local installed=$(get_config ".available_models.\"$model_key\".installed")
    if [ "$installed" != "true" ]; then
        echo "❌ Model '$model_key' is not installed. Run: $0 install $model_key"
        return 1
    fi
    
    set_config ".active_model = \"$model_key\""
    echo "✅ Switched active model to: $model_key ($model_name)"
}

# List available models
list_models() {
    echo "📋 Available Models:"
    echo "===================="
    
    get_config '.available_models | to_entries[]' | jq -r '
        "\(.key): \(.value.name) | \(.value.description) | Installed: \(.value.installed // false)"
    '
    
    local active=$(get_config '.active_model')
    echo ""
    echo "🎯 Active Model: $active"
}

# Remove a model
remove_model() {
    local model_key=$1
    local model_name=$(get_config ".available_models.\"$model_key\".name")
    
    if [ -z "$model_name" ] || [ "$model_name" = "null" ]; then
        echo "❌ Model '$model_key' not found"
        return 1
    fi
    
    echo "🗑️ Removing model: $model_name"
    ollama rm "$model_name"
    
    set_config ".available_models.\"$model_key\".installed = false"
    echo "✅ Model '$model_name' removed"
}

# Show current status
status() {
    echo "🤖 AI Assistant Status"
    echo "====================="
    
    # Check if Ollama is running
    # Cross-platform service check
    if command -v pacman >/dev/null 2>&1 && uname -r | grep -q "MINGW\|MSYS"; then
        if pgrep -x "ollama" > /dev/null; then
            echo "✅ Ollama service: RUNNING"
        else
            echo "❌ Ollama service: STOPPED"
        fi
    else
        if systemctl is-active --quiet ollama; then
            echo "✅ Ollama service: RUNNING"
        else
            echo "❌ Ollama service: STOPPED"
        fi
    fi
    
    local active_model=$(get_config '.active_model')
    local active_model_name=$(get_config ".available_models.\"$active_model\".name")
    
    echo "🎯 Active Model: $active_model ($active_model_name)"
    
    echo ""
    echo "📊 Installed Models:"
    ollama list
}

# Main command handler
case "$1" in
    install)
        if [ -z "$2" ]; then
            install_all_models
        else
            install_model "$2"
        fi
        ;;
    switch)
        if [ -z "$2" ]; then
            echo "Usage: $0 switch <model_key>"
            echo "Available models:"
            get_config '.available_models | keys[]' | while read -r key; do
                echo "  - $key"
            done
            exit 1
        fi
        switch_model "$2"
        ;;
    list)
        list_models
        ;;
    remove)
        if [ -z "$2" ]; then
            echo "Usage: $0 remove <model_key>"
            exit 1
        fi
        remove_model "$2"
        ;;
    status)
        status
        ;;
    *)
        echo "Usage: $0 {install|switch|list|remove|status} [model_key]"
        echo ""
        echo "Commands:"
        echo "  install [model]    Install all models or specific model"
        echo "  switch <model>     Switch active model"
        echo "  list               List all available models"
        echo "  remove <model>     Remove a specific model"
        echo "  status             Show current status"
        echo ""
        echo "Example:"
        echo "  $0 install          # Install all models"
        echo "  $0 install codellama # Install only codellama"
        echo "  $0 switch mistral   # Switch to mistral model"
        exit 1
        ;;
esac
