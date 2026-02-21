sudo systemctl daemon-reload && systemctl restart ollama && netstat -tulpn | grep 11434 && ufw status

#!/bin/bash

# -----------------------------------------------------------------------------
# Ollama Network Configuration and Restart Script
# For Linux Mint with GTX 960M
# -----------------------------------------------------------------------------

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Colour

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Function to run sudo commands with a single password prompt
run_sudo_commands() {
    # Ask for sudo password once at the beginning
    sudo -v
    
    # Keep sudo alive in the background
    while true; do
        sudo -n true
        sleep 60
        kill -0 "$$" 2>/dev/null || exit
    done 2>/dev/null &
}

# Function to check if Ollama service exists
check_ollama_installed() {
    if ! systemctl list-unit-files | grep -q ollama.service; then
        print_error "Ollama service not found. Is Ollama installed?"
        exit 1
    fi
}

# Function to check current configuration
check_current_config() {
    print_step "Checking current Ollama configuration..."
    
    # Check if override file exists
    if [ -f /etc/systemd/system/ollama.service.d/override.conf ]; then
        echo "Current override configuration:"
        cat /etc/systemd/system/ollama.service.d/override.conf
    else
        print_warn "No override configuration found"
    fi
    
    # Check current listening address
    echo ""
    echo "Current network status:"
    sudo netstat -tulpn 2>/dev/null | grep 11434 || echo "Ollama not listening on port 11434"
    
    # Check UFW status
    echo ""
    if command -v ufw &> /dev/null; then
        echo "UFW Status:"
        sudo ufw status | grep -q "Status: active" && echo "  UFW is active" || echo "  UFW is inactive"
        sudo ufw status | grep 11434 && echo "  ✓ Port 11434 rule exists" || echo "  ✗ No rule for port 11434"
    else
        print_warn "UFW not installed"
    fi
}

# Function to configure Ollama for network access
configure_ollama() {
    print_step "Configuring Ollama for network access..."
    
    # Create override directory if it doesn't exist
    sudo mkdir -p /etc/systemd/system/ollama.service.d/
    
    # Create or update override.conf
    cat << 'EOF' | sudo tee /etc/systemd/system/ollama.service.d/override.conf > /dev/null
[Service]
# Allow connections from any network interface
Environment="OLLAMA_HOST=0.0.0.0"
# Allow cross-origin requests (useful for web apps)
Environment="OLLAMA_ORIGINS=*"
# Keep models loaded for 10 minutes (good for memory management)
Environment="OLLAMA_KEEP_ALIVE=10m"
# Limit to 2 models simultaneously (saves VRAM on GTX 960M)
Environment="OLLAMA_MAX_LOADED_MODELS=2"
# Process one request at a time
Environment="OLLAMA_NUM_PARALLEL=1"
EOF
    
    print_info "✓ Ollama configuration updated"
    
    # Reload systemd
    print_step "Reloading systemd configuration..."
    sudo systemctl daemon-reload
    print_info "✓ Systemd reloaded"
}

# Function to restart Ollama
restart_ollama() {
    print_step "Restarting Ollama service..."
    
    # Stop Ollama
    sudo systemctl stop ollama
    sleep 2
    
    # Clear any lingering processes
    sudo pkill -f ollama 2>/dev/null || true
    sleep 2
    
    # Start Ollama
    sudo systemctl start ollama
    
    # Wait for service to start
    echo "Waiting for Ollama to start..."
    for i in {1..10}; do
        sleep 1
        if systemctl is-active --quiet ollama; then
            print_info "✓ Ollama started successfully"
            break
        fi
        if [ $i -eq 10 ]; then
            print_error "Failed to start Ollama"
            exit 1
        fi
    done
    
    # Enable to start on boot
    sudo systemctl enable ollama > /dev/null 2>&1
}

# Function to configure firewall
configure_firewall() {
    print_step "Configuring firewall for network access..."
    
    # Check if UFW is installed
    if ! command -v ufw &> /dev/null; then
        print_warn "UFW not installed. Installing..."
        sudo apt-get update > /dev/null 2>&1
        sudo apt-get install -y ufw > /dev/null 2>&1
    fi
    
    # Get local network
    LOCAL_IP=$(ip route get 1 | awk '{print $NF;exit}')
    LOCAL_NETWORK=$(ip route | grep -v default | grep $LOCAL_IP | awk '{print $1}')
    
    if [ -z "$LOCAL_NETWORK" ]; then
        # Fallback to common home networks
        LOCAL_NETWORK="192.168.1.0/24"
        print_warn "Could not detect network, using $LOCAL_NETWORK"
    else
        print_info "Detected local network: $LOCAL_NETWORK"
    fi
    
    # Check if rule already exists
    if sudo ufw status | grep -q 11434; then
        print_info "Firewall rule for port 11434 already exists"
        echo "Current rules:"
        sudo ufw status | grep 11434
    else
        # Add firewall rule
        echo "Adding firewall rule for $LOCAL_NETWORK to access port 11434..."
        sudo ufw allow from $LOCAL_NETWORK to any port 11434 proto tcp
        
        # Enable UFW if not active (with caution)
        if ! sudo ufw status | grep -q "Status: active"; then
            print_warn "UFW is not active. Enabling UFW..."
            echo "y" | sudo ufw enable
        else
            sudo ufw reload
        fi
        
        print_info "✓ Firewall configured"
    fi
}

# Function to verify setup
verify_setup() {
    print_step "Verifying setup..."
    
    # Check if Ollama is running
    if ! systemctl is-active --quiet ollama; then
        print_error "Ollama is not running"
        return 1
    fi
    
    # Check listening address
    LISTEN_OUTPUT=$(sudo netstat -tulpn 2>/dev/null | grep 11434)
    if echo "$LISTEN_OUTPUT" | grep -q "0.0.0.0:11434"; then
        print_info "✓ Ollama is listening on all interfaces (0.0.0.0:11434)"
    else
        print_warn "Ollama is only listening locally:"
        echo "$LISTEN_OUTPUT"
    fi
    
    # Get local IP
    LOCAL_IP=$(ip route get 1 2>/dev/null | awk '{print $NF;exit}')
    if [ -n "$LOCAL_IP" ]; then
        echo ""
        echo "Your Ollama server IP: $LOCAL_IP"
        echo ""
        echo "Test from another computer on your network with:"
        echo -e "${GREEN}curl http://$LOCAL_IP:11434/api/generate -d '{\"model\":\"deepseek-coder:1.3b\",\"prompt\":\"hello\"}'${NC}"
    fi
}

# Function to show menu
show_menu() {
    clear
    cat << "EOF"
╔══════════════════════════════════════════╗
║     Ollama Network Configuration Tool    ║
║        for Linux Mint + GTX 960M         ║
╚══════════════════════════════════════════╝
EOF
    echo ""
    echo "1) Quick restart (just restart service)"
    echo "2) Full reconfigure (update settings + restart)"
    echo "3) Check current status only"
    echo "4) Remove network access (revert to localhost only)"
    echo "5) Exit"
    echo ""
    read -p "Select option [1-5]: " menu_choice
}

# Function to remove network access
remove_network_access() {
    print_step "Removing network access configuration..."
    
    # Remove override file
    if [ -f /etc/systemd/system/ollama.service.d/override.conf ]; then
        sudo rm /etc/systemd/system/ollama.service.d/override.conf
        print_info "✓ Removed override configuration"
    fi
    
    # Reload and restart
    sudo systemctl daemon-reload
    sudo systemctl restart ollama
    
    # Remove firewall rule
    if command -v ufw &> /dev/null; then
        RULE_NUM=$(sudo ufw status numbered | grep 11434 | awk -F'[][]' '{print $2}')
        if [ -n "$RULE_NUM" ]; then
            echo "y" | sudo ufw delete $RULE_NUM
            print_info "✓ Removed firewall rule"
        fi
    fi
    
    print_info "Ollama is now only accessible from localhost"
}

# Main execution
main() {
    # Check if running as root (we don't want that)
    if [ "$EUID" -eq 0 ]; then 
        print_error "Please don't run this script as root directly"
        print_info "The script will ask for sudo when needed"
        exit 1
    fi
    
    # Show menu
    show_menu
    
    case $menu_choice in
        1)
            # Quick restart
            run_sudo_commands
            check_ollama_installed
            restart_ollama
            verify_setup
            ;;
        2)
            # Full reconfigure
            run_sudo_commands
            check_ollama_installed
            check_current_config
            echo ""
            read -p "Continue with full reconfiguration? (y/n) " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                configure_ollama
                restart_ollama
                configure_firewall
                verify_setup
            fi
            ;;
        3)
            # Check only
            run_sudo_commands
            check_ollama_installed
            check_current_config
            verify_setup
            ;;
        4)
            # Remove network access
            run_sudo_commands
            check_ollama_installed
            remove_network_access
            verify_setup
            ;;
        5)
            print_info "Exiting"
            exit 0
            ;;
        *)
            print_error "Invalid option"
            exit 1
            ;;
    esac
    
    echo ""
    print_info "Done!"
}

# Run main function
main
