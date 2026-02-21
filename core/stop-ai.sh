#!/bin/bash
# save as stop-ai-assistant.sh

echo "🛑 Stopping AI Assistant services..."

# Stop Ollama
echo "Stopping Ollama..."
sudo systemctl stop ollama

# Remove firewall rules for Ollama (safety)
if command -v ufw &> /dev/null; then
    if sudo ufw status | grep -q 11434; then
        echo "🔒 Removing firewall rule for port 11434..."
        # Get rule numbers for port 11434
        RULE_NUMS=$(sudo ufw status numbered | grep 11434 | awk -F'[][]' '{print $2}' | sort -rn)
        for RULE_NUM in $RULE_NUMS; do
            echo "y" | sudo ufw delete $RULE_NUM > /dev/null 2>&1
        done
        echo "✅ Firewall rules removed"
    else
        echo "✅ No firewall rules found for port 11434"
    fi
fi

# Check if VS Code is running and suggest closing it
if pgrep -x "code" > /dev/null; then
    echo "⚠️  VS Code is still running. Close it to stop the Continue extension."
else
    echo "✅ VS Code is closed (Continue LSP stopped)"
fi

# Show final status
echo ""
echo "📊 Current status:"
systemctl status ollama --no-pager | grep "Active:"
echo ""
echo "To restart later: sudo systemctl start ollama"
echo "Note: Firewall rules will need to be re-added when restarting"
