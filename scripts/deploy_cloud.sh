#!/bin/bash

# Cloud Deployment Script
set -e

echo "☁️ Deploying AI Assistant to Cloud..."

# This script assumes you're on a fresh cloud instance (AWS EC2, Google Cloud, etc.)

# Run the main setup
chmod +x setup_ai_assistant.sh
./setup_ai_assistant.sh

# Make all scripts executable
chmod +x scripts/*.sh
chmod +x examples/*.sh

# Install models (you can modify this to install only specific models)
echo "📥 Installing models..."
./scripts/model_manager.sh install codellama

# Start services
./scripts/service_manager.sh start

# Set up authentication token (change this for security)
echo "export AI_ASSISTANT_TOKEN=\"your-secret-token-here\"" >> ~/.bashrc
source ~/.bashrc

echo "✅ Deployment completed!"
echo ""
echo "📋 Next steps:"
echo "1. Configure your cloud firewall to allow port 8000"
echo "2. Update the AI_ASSISTANT_TOKEN in ~/.bashrc for security"
echo "3. Test the API with: ./examples/usage_examples.sh"
echo "4. Install additional models: ./scripts/model_manager.sh install <model>"
echo ""
echo "🌐 Your API will be available at: http://$(curl -s ifconfig.me):8000"
