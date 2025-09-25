#!/bin/bash

# GPU Setup for NVIDIA cards (GTX 950M)
set -e

echo "🎮 Setting up NVIDIA GPU support..."

# Check if NVIDIA card is present
if ! lspci | grep -i nvidia > /dev/null; then
    echo "❌ No NVIDIA GPU detected. Will run on CPU only."
    exit 1
fi

# Install NVIDIA drivers (Ubuntu/Debian)
sudo apt update
sudo apt install -y nvidia-driver-470  # Legacy driver for GTX 950M

# Install CUDA toolkit (optional, but helps with some models)
# sudo apt install -y nvidia-cuda-toolkit

# Install Ollama with GPU support
curl -fsSL https://ollama.ai/install.sh | sh

# Configure Ollama to use GPU
export OLLAMA_GPU_DRIVER="nvidia"

# Test GPU detection
echo "🔍 Testing GPU detection..."
ollama serve &
sleep 5

if ollama ps | grep -q "gpu"; then
    echo "✅ GPU acceleration enabled"
else
    echo "⚠️  GPU not detected by Ollama, will use CPU"
fi

echo "💡 Tips for GTX 950M:"
echo "   - Use quantized models (q4_0, q5_0)"
echo "   - Start with tinyllama for testing"
echo "   - Monitor VRAM usage with 'nvidia-smi'"
