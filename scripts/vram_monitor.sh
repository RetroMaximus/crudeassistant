#!/bin/bash

# VRAM monitoring for limited GPU memory
monitor_vram() {
    while true; do
        clear
        echo "🎮 GPU VRAM Monitor (GTX 950M)"
        echo "================================"
        nvidia-smi --query-gpu=memory.total,memory.used,memory.free --format=csv
        echo ""
        echo "📊 Ollama Models Loaded:"
        ollama list
        echo ""
        echo "Press Ctrl+C to exit"
        sleep 5
    done
}

# Check if NVIDIA tools are available
if ! command -v nvidia-smi &> /dev/null; then
    echo "❌ nvidia-smi not found. Running in CPU mode."
    echo "💡 Install NVIDIA drivers: sudo apt install nvidia-driver-470"
    exit 1
fi

monitor_vram
