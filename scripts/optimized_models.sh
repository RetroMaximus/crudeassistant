#!/bin/bash

# Optimized models for limited hardware (2-4GB VRAM)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../config/models.json"

# Create optimized model configuration for low VRAM
cat > "$CONFIG_FILE" << 'EOF'
{
    "available_models": {
        "tinyllama": {
            "name": "tinyllama:1.1b",
            "description": "Very small model, runs on CPU/RAM only if needed",
            "tags": ["coding", "fast", "low-resource"],
            "default_temperature": 0.2,
            "vram_required": 1,
            "parameters": "1.1B"
        },
        "phi2": {
            "name": "phi:2.7b",
            "description": "Small but capable model, good for coding",
            "tags": ["coding", "efficient", "low-resource"],
            "default_temperature": 0.3,
            "vram_required": 3,
            "parameters": "2.7B"
        },
        "codellama7b-q4": {
            "name": "codellama:7b-q4_0",
            "description": "4-bit quantized CodeLlama, best for coding",
            "tags": ["coding", "quantized", "balanced"],
            "default_temperature": 0.2,
            "vram_required": 4,
            "parameters": "7B (4-bit)"
        },
        "mistral7b-q4": {
            "name": "mistral:7b-q4_0",
            "description": "4-bit quantized Mistral, good general purpose",
            "tags": ["general", "quantized", "balanced"],
            "default_temperature": 0.3,
            "vram_required": 4,
            "parameters": "7B (4-bit)"
        }
    },
    "active_model": "tinyllama",
    "hardware_mode": "low-vram"
}
EOF

echo "✅ Optimized model configuration created for low VRAM hardware"
