#!/bin/bash

# AI Assistant Cloud Setup Script
set -e

echo "🚀 Setting up AI Assistant..."

# Detect package manager
if command -v pacman >/dev/null 2>&1 && uname -r | grep -q "MINGW\|MSYS"; then
    PACKAGE_MANAGER="pacman"
    echo "📦 Detected MSYS2/pacman system"
elif command -v apt >/dev/null 2>&1; then
    PACKAGE_MANAGER="apt"
    echo "📦 Detected Debian/apt system"
else
    echo "❌ Unsupported system - only apt and pacman supported"
    exit 1
fi

# Update system
if [ "$PACKAGE_MANAGER" = "apt" ]; then
    sudo apt update && sudo apt upgrade -y
    sudo apt install -y curl wget python3 python3-pip python3-venv nginx certbot python3-certbot-nginx
elif [ "$PACKAGE_MANAGER" = "pacman" ]; then
    sudo pacman -Syu --noconfirm
    sudo pacman -S --noconfirm curl wget python python-pip nginx certbot
fi

# Install Ollama
curl -fsSL https://ollama.ai/install.sh | sh

# Create application directory
mkdir -p ~/ai-assistant
cd ~/ai-assistant

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install fastapi uvicorn python-jose[cryptography] passlib[bcrypt] python-multipart

# Create SSL directory
mkdir -p ssl

echo "✅ Setup completed! Run './scripts/setup_ssl.sh' to configure HTTPS"