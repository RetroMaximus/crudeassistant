#!/bin/bash
# save as assign-target-ip-port.sh

# ===== Configuration =====
CONFIG_DIR="$HOME/.config/llm-target"
CONFIG_FILE="$CONFIG_DIR/target.conf"
# ========================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Function to validate IP
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        for octet in $(echo $ip | tr "." " "); do
            if [ $octet -gt 255 ]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Function to mask IP for display
mask_ip() {
    local ip="$1"
    if [[ "$ip" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
        echo "${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}.XXX"
    else
        echo "XXX.XXX.XXX.XXX"
    fi
}

# Function to mask port for display
mask_port() {
    local port="$1"
    if [ ${#port} -gt 1 ]; then
        echo "${port:0:1}$(printf '%*s' $((${#port}-1)) | tr ' ' 'X')"
    else
        echo "X"
    fi
}

# Parse command line arguments
if [ "$#" -eq 1 ]; then
    # Format: ./assign-target-ip-port.sh 192.168.1.12:11434
    if [[ "$1" =~ ^([0-9.]+):([0-9]+)$ ]]; then
        TARGET_IP="${BASH_REMATCH[1]}"
        TARGET_PORT="${BASH_REMATCH[2]}"
    else
        print_error "Invalid format. Use: IP:PORT (e.g., 192.168.1.12:11434)"
        exit 1
    fi
elif [ "$#" -eq 2 ]; then
    # Format: ./assign-target-ip-port.sh 192.168.1.12 11434
    TARGET_IP="$1"
    TARGET_PORT="$2"
else
    # Interactive mode
    echo "🌐 LLM Target Configuration"
    echo "=========================="
    
    # Show current config if exists
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo "Current target: $TARGET_IP_MASKED:$TARGET_PORT_MASKED"
        echo ""
    fi
    
    read -p "Enter target IP address: " TARGET_IP
    read -p "Enter target port [11434]: " TARGET_PORT
    TARGET_PORT=${TARGET_PORT:-11434}
fi

# Validate inputs
if ! validate_ip "$TARGET_IP"; then
    print_error "Invalid IP address format"
    exit 1
fi

if ! [[ "$TARGET_PORT" =~ ^[0-9]+$ ]] || [ "$TARGET_PORT" -lt 1 ] || [ "$TARGET_PORT" -gt 65535 ]; then
    print_error "Invalid port number (must be 1-65535)"
    exit 1
fi

# Create config directory
mkdir -p "$CONFIG_DIR"

# Create masked versions
IP_MASKED=$(mask_ip "$TARGET_IP")
PORT_MASKED=$(mask_port "$TARGET_PORT")

# Save configuration
cat > "$CONFIG_FILE" << EOF
# LLM Target Configuration
# Created: $(date)
# WARNING: This file contains sensitive information

TARGET_IP="$TARGET_IP"
TARGET_PORT="$TARGET_PORT"
TARGET_IP_MASKED="$IP_MASKED"
TARGET_PORT_MASKED="$PORT_MASKED"
EOF

chmod 600 "$CONFIG_FILE"

print_info "Target configuration saved"
echo "  IP:  $IP_MASKED"
echo "  Port: $PORT_MASKED"

# Test connection
echo ""
read -p "Test connection to target? (y/n): " test_conn
if [[ $test_conn =~ ^[Yy]$ ]]; then
    if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${TARGET_IP}:${TARGET_PORT}/api/tags" 2>/dev/null | grep -q "200"; then
        print_info "✓ Successfully connected to $IP_MASKED:$PORT_MASKED"
    else
        print_warn "Could not connect to $IP_MASKED:$PORT_MASKED"
        echo "  Check if the server is running and reachable"
    fi
fi
