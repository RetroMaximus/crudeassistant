#!/bin/bash
# save as ask-llm.sh

CONFIG_DIR="$HOME/.config/llm-target"
CONFIG_FILE="$CONFIG_DIR/target.conf"
# ========================

export MSYS2_ARG_CONV_EXCL="*"
export MSYS_NO_PATHCONV=1

# Default values
MODEL="deepseek-coder:1.3b"
AS_CLIENT=false
TARGET_IP="localhost"
TARGET_PORT="11434"

# Load target config if it exists and we're in client mode
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    # Check if we're on the target machine (simple check - if ip matches local)
    LOCAL_IPS=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' 2>/dev/null || echo "")
    if [[ "$LOCAL_IPS" == *"$TARGET_IP"* ]]; then
        AS_CLIENT=false
    else
        AS_CLIENT=true
    fi
fi

if [ "$AS_CLIENT" = true ]; then
    ENDPOINT="http://${TARGET_IP}:${TARGET_PORT}/api/generate"
    # Show masked values
    source "$CONFIG_FILE"
    echo "🌐 Sending to remote: ${TARGET_IP_MASKED}:${TARGET_PORT_MASKED}" >&2
else
    ENDPOINT="http://localhost:11434/api/generate"
fi

# Parse arguments
if [ "$#" -eq 0 ]; then
    echo "Usage: $0 [model-alias] \"Your question here\""
    echo "   or:  echo \"Your question\" | $0 [model-alias]"
    exit 1
fi

case $1 in
    "deepseek"|"ds") MODEL="deepseek-coder:1.3b"; shift ;;
    "qwen"|"q") MODEL="qwen2.5-coder:1.5b"; shift ;;
    "phi"|"phi3") MODEL="phi3:mini"; shift ;;
    "tiny"|"tinyllama") MODEL="tinyllama"; shift ;;
    "codellama"|"cl") MODEL="codellama:7b"; shift ;;
    "mistral"|"m") MODEL="mistral:7b"; shift ;;
esac

if [ ! -t 0 ]; then
    PROMPT=$(cat)
elif [ "$#" -gt 0 ]; then
    PROMPT="$*"
else
    echo "Error: No prompt provided"
    exit 1
fi

ESCAPED_PROMPT=$(echo "$PROMPT" | sed 's/"/\\"/g')

RESPONSE=$(curl -s --connect-timeout 10 -X POST "$ENDPOINT" \
    -H "Content-Type: application/json" \
    -d "{
  \"model\": \"$MODEL\",
  \"prompt\": \"$ESCAPED_PROMPT\",
  \"stream\": false
}" 2>&1)

if [ $? -ne 0 ] || [ -z "$RESPONSE" ]; then
    echo "❌ Error: Failed to get response from Ollama"
    exit 1
fi

if echo "$RESPONSE" | grep -q '"error"'; then
    ERROR_MSG=$(echo "$RESPONSE" | sed -n 's/.*"error":"\([^"]*\)".*/\1/p')
    echo "❌ Ollama error: $ERROR_MSG"
    exit 1
fi

# Code parser with improved code block detection - USING HERE-DOCUMENT
if command -v python3 &> /dev/null; then
    python3 -c "$(cat << 'EOF'
import sys, json, re

try:
    data = json.load(sys.stdin)
    if 'response' in data:
        response = data['response']
        
        # Clean up markdown code blocks with language detection
        lines = response.split('\n')
        in_code_block = False
        current_lang = ''
        cleaned_lines = []
        
        i = 0
        while i < len(lines):
            line = lines[i]
            
            # Check for code block start (``` or ```language)
            code_block_match = re.match(r'^\s*```(\w*)\s*$', line)
            
            if code_block_match and not in_code_block:
                # Start of code block
                current_lang = code_block_match.group(1)
                if current_lang:
                    cleaned_lines.append(f'```{current_lang}')
                else:
                    cleaned_lines.append('```')
                in_code_block = True
                i += 1
                continue
                
            elif in_code_block and re.match(r'^\s*```\s*$', line):
                # End of code block
                cleaned_lines.append('```')
                in_code_block = False
                current_lang = ''
                cleaned_lines.append('')  # Add blank line after code block
                i += 1
                continue
                
            elif in_code_block:
                # Inside code block - preserve content exactly
                cleaned_lines.append(line)
                i += 1
                continue
                
            else:
                # Outside code block - clean up stray backticks
                line = re.sub(r'`+', '', line)
                cleaned_lines.append(line)
                i += 1
        
        # If we're still in a code block at the end, close it properly
        if in_code_block:
            cleaned_lines.append('```')
        
        # Join and print
        print('\n'.join(cleaned_lines).rstrip())
    else:
        sys.exit(1)
except Exception as e:
    sys.exit(1)
EOF
)" <<< "$RESPONSE" && echo "" && exit 0
fi

# Fallback sed parser with better code block handling
echo "$RESPONSE" | sed -n 's/.*"response":"\(.*\)","done".*/\1/p' | \
    sed 's/\\n/\n/g' | \
    sed 's/\\"/"/g' | \
    sed 's/\\\\/\\/g' | \
    # Ensure code blocks are properly formatted
    sed -E 's/```([a-zA-Z]*)/```\1\n/g' | \
    # Add newline after closing code blocks
    sed -E 's/```/```\n\n/g'

echo ""
