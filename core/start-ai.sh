#!/bin/bash
# save as start-ai-assistant.sh

echo "🚀 Starting AI Assistant services..."

# Start Ollama
echo "Starting Ollama..."
sudo systemctl start ollama

# Re-add firewall rules
if command -v ufw &> /dev/null; then
    echo "🔓 Adding firewall rule for port 11434..."
    # Detect local network
    LOCAL_IP=$(ip route get 1 2>/dev/null | awk '{print $NF;exit}')
    LOCAL_NETWORK=$(ip route | grep -v default | grep $LOCAL_IP | awk '{print $1}')
    
    if [ -z "$LOCAL_NETWORK" ]; then
        LOCAL_NETWORK="192.168.1.0/24"
        echo "⚠️  Using default network: $LOCAL_NETWORK"
    else
        echo "📡 Detected network: $LOCAL_NETWORK"
    fi
    
    sudo ufw allow from $LOCAL_NETWORK to any port 11434 proto tcp > /dev/null 2>&1
    echo "✅ Firewall rule added"
fi

# Wait for Ollama to be ready
echo "⏳ Waiting for Ollama to be ready..."
sleep 3

# Show final status
echo ""
echo "📊 Current status:"
systemctl status ollama --no-pager | grep "Active:"

# Show IP for remote access
LOCAL_IP=$(ip route get 1 2>/dev/null | awk '{print $NF;exit}')
if [ -n "$LOCAL_IP" ]; then
    echo ""
    echo "🌐 Remote access available at: http://$LOCAL_IP:11434"
    echo "   Test with: curl http://$LOCAL_IP:11434/api/tags"
fi
