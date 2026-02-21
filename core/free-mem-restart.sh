# Stop Ollama completely
sudo systemctl stop ollama

# Clear any remaining Ollama processes
pkill -f ollama

# Check memory usage
free -h

# Restart when needed
sudo systemctl start ollama
