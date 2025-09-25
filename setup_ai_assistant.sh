#!/bin/bash

# AI Assistant Cloud Setup Script with Multi-Model Support
set -e

echo "🚀 Setting up AI Assistant with Multi-Model Support..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y curl wget python3 python3-pip python3-venv nginx jq certbot python3-certbot-nginx

# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Create application directory structure
mkdir -p ~/ai-assistant/{models,scripts,logs,config}
cd ~/ai-assistant

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install fastapi uvicorn python-jose[cryptography] passlib[bcrypt] python-multipart requests pydantic 

# Create configuration files
cat > config/models.json << 'EOF'
{
    "available_models": {
        "codellama": {
            "name": "codellama:7b",
            "description": "Code-focused model for programming assistance",
            "tags": ["coding", "programming"],
            "default_temperature": 0.2
        },
        "llama2": {
            "name": "llama2:7b",
            "description": "General purpose model",
            "tags": ["general", "conversation"],
            "default_temperature": 0.7
        },
        "mistral": {
            "name": "mistral:7b",
            "description": "Efficient model for reasoning",
            "tags": ["reasoning", "efficient"],
            "default_temperature": 0.3
        },
        "phi": {
            "name": "phi:2.7b",
            "description": "Small but capable model",
            "tags": ["fast", "lightweight"],
            "default_temperature": 0.4
        }
    },
    "active_model": "codellama"
}
EOF

echo "✅ Setup completed! Run './scripts/install_models.sh' to install models."
