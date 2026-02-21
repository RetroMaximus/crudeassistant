#!/bin/bash
# save as toggle-target-mask.sh

# ===== Configuration =====
CONFIG_DIR="$HOME/.config/llm-target"
CONFIG_FILE="$CONFIG_DIR/target.conf"
MASK_STATE_FILE="$CONFIG_DIR/mask_state"
# ========================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "No target configuration found."
    echo "Run ./assign-target-ip-port.sh first."
    exit 1
fi

# Load config
source "$CONFIG_FILE"

# Load or initialize mask state
if [ -f "$MASK_STATE_FILE" ]; then
    MASKED=$(cat "$MASK_STATE_FILE")
else
    MASKED=true  # Default to masked
fi

# Toggle state
if [ "$1" = "on" ]; then
    MASKED=true
elif [ "$1" = "off" ]; then
    MASKED=false
else
    # Toggle
    if [ "$MASKED" = "true" ]; then
        MASKED=false
    else
        MASKED=true
    fi
fi

# Save state
echo "$MASKED" > "$MASK_STATE_FILE"

# Display current configuration
echo "📡 LLM Target Configuration"
echo "=========================="

if [ "$MASKED" = "true" ]; then
    echo "IP:   $TARGET_IP_MASKED (masked)"
    echo "Port: $TARGET_PORT_MASKED (masked)"
    echo ""
    echo "Run '$0 off' to show actual values"
else
    echo "IP:   $TARGET_IP (unmasked)"
    echo "Port: $TARGET_PORT (unmasked)"
    echo ""
    echo "⚠️  Actual values are displayed!"
    echo "Run '$0 on' to mask again"
fi

echo ""
echo "Current mask state: $([ "$MASKED" = "true" ] && echo "ON" || echo "OFF")"
