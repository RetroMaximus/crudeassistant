#!/bin/bash

# Usage examples for the AI Assistant
echo "🤖 AI Assistant Usage Examples"
echo "=============================="

# Set the API base URL (replace with your cloud instance IP)
API_BASE="http://localhost:8000"
AUTH_TOKEN="free-tier-token"

# Function to make API calls
api_call() {
    local endpoint=$1
    local data=$2
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -d "$data" \
        "$API_BASE$endpoint"
}

# Example 1: List available models
echo "1. Listing available models:"
curl -s "$API_BASE/models" | jq .

# Example 2: Switch to a different model
echo -e "\n2. Switching to mistral model:"
api_call "/models/switch" '{"model_key": "mistral"}'

# Example 3: Ask a coding question with JSON response
echo -e "\n3. Asking coding question:"
api_call "/chat" '{
    "message": "Create a Python function to calculate fibonacci sequence up to n numbers",
    "json_mode": true,
    "temperature": 0.2,
    "low_memory": true
}'

# Example 4: Ask for planning advice
#echo -e "\n4. Asking planning question:"
#api_call "/chat" '{
#    "message": "Create a project plan for building a web application #with React and FastAPI",
#    "model": "llama2",
#    "json_mode": true,
#    "low_memory": true
#}'

# Example 5: Check system status
echo -e "\n5. System status:"
curl -s "$API_BASE/status" | jq .