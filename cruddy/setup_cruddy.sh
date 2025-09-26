#!/bin/bash

# Cruddy Robot Setup Script
set -e

echo "🤖 Setting up Cruddy Robot..."

# Detect platform
if command -v pacman >/dev/null 2>&1; then
    echo "📦 MSYS2/Arch detected - some hardware features may be limited"
else
    echo "📦 Linux detected - full hardware support available"
fi

# Create robot directory
mkdir -p ~/cruddy-robot
cd ~/cruddy-robot

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install robot dependencies
pip install requests pyaudio gtts pygame RPi.GPIO

# Create config file
cat > config.json << 'EOF'
{
    "api_url": "https://localhost:8000",
    "auth_token": "free-tier-token",
    "tts_voice": "en-US-Wavenet-D",
    "servo_pins": {
        "head": 18,
        "left_arm": 17, 
        "right_arm": 27
    },
    "wheel_pins": {
        "left_forward": 23,
        "left_backward": 24,
        "right_forward": 25,
        "right_backward": 26
    }
}
EOF

echo "✅ Cruddy robot setup complete!"
echo "📝 Edit ~/cruddy-robot/config.json with your API server details"
