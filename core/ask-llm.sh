#!/bin/bash
# save as ask-llm.sh

# ===== Configuration =====
CONFIG_DIR="$HOME/.config/llm-target"
CONFIG_FILE="$CONFIG_DIR/target.conf"
MASK_STATE_FILE="$CONFIG_DIR/mask_state"
# ========================

export MSYS2_ARG_CONV_EXCL="*"
export MSYS_NO_PATHCONV=1

# Default values
MODEL="deepseek-coder:1.3b"
AS_CLIENT=false
TARGET_IP="localhost"
TARGET_PORT="11434"

# Load target config if it exists
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    # Check if we're on the target machine - more robust method
    AS_CLIENT=false
    
    # Try multiple methods to get local IPs
    LOCAL_IPS=""
    
    # Method 1: ip command (Linux)
    if command -v ip &> /dev/null; then
        LOCAL_IPS=$(ip -4 addr show 2>/dev/null | grep -oE 'inet [0-9.]+' | cut -d' ' -f2)
    fi
    
    # Method 2: ifconfig (older systems)
    if [ -z "$LOCAL_IPS" ] && command -v ifconfig &> /dev/null; then
        LOCAL_IPS=$(ifconfig 2>/dev/null | grep -oE 'inet [0-9.]+' | cut -d' ' -f2)
    fi
    
    # Method 3: hostname (fallback)
    if [ -z "$LOCAL_IPS" ] && command -v hostname &> /dev/null; then
        LOCAL_IPS=$(hostname -I 2>/dev/null)
    fi
    
    # Method 4: Windows/MSYS2
    if [ -z "$LOCAL_IPS" ] && command -v netsh &> /dev/null; then
        LOCAL_IPS=$(netsh interface ip show address 2>/dev/null | grep -oE 'IP Address: [0-9.]+' | cut -d' ' -f3)
    fi
    
    # Check if target IP matches any local IP
    for local_ip in $LOCAL_IPS; do
        if [ "$local_ip" = "$TARGET_IP" ]; then
            AS_CLIENT=false
            break
        else
            AS_CLIENT=true
        fi
    done
fi
# Load mask state
if [ -f "$MASK_STATE_FILE" ]; then
    MASKED=$(cat "$MASK_STATE_FILE")
else
    MASKED=true  # Default to masked
fi

show_help() {
    cat << EOF
╔══════════════════════════════════════════════════════════════╗
║                    LLM Assistant Helper                      ║
╚══════════════════════════════════════════════════════════════╝

USAGE:
  $0 [model-alias] "Your question here"
  $0 [command] [arguments]

COMMANDS:
  help                          Show this help message
  
  config                        Show current target configuration
  config set <ip:port>          Set target IP and port (e.g., 192.168.1.12:11434)
  config set <ip> <port>        Set target IP and port separately
  config show                   Show current configuration (respects mask)
  config mask on/off            Toggle IP masking on/off
  config test                   Test connection to target
  
  models                        List available models and aliases
  ps                            Show currently loaded models
  pull <model>                  Pull a new model
  
  free-mem/freemem              free memory then restart. (Likely if its full for low level GPU's)

  host                          Switch to host mode (local)
  client                        Switch to client mode (remote)

AVAILABLE SCRIPTS:
  ./assign-target-ip-port.sh    Configure target IP and port
  ./toggle-target-mask.sh       Toggle IP address masking
  ./restart-ollama.sh           Restart Ollama service
  ./free-mem-restart.sh         Clear memory and restart Ollama
  ./start-ai.sh                 Start Ollama and firewall
  ./stop-ai.sh                  Stop Ollama and remove firewall
  ./manage-model-rules.sh       Create custom models

MODEL ALIASES:
  deepseek, ds  -> deepseek-coder:1.3b
  qwen, q       -> qwen2.5-coder:1.5b
  phi, phi3     -> phi3:mini
  tiny, tinyllama -> tinyllama
  codellama, cl -> codellama:7b
  mistral, m    -> mistral:7b

EXAMPLES:
  $0 "Write a Python function"           # Use default model
  $0 ds "Explain recursion"               # Use deepseek alias
  $0 config set 192.168.1.12:11434        # Set target
  $0 config mask on                       # Enable IP masking
  $0 ps                                   # Show loaded models
  ./free-mem-restart.sh                    # Clear memory on server
  ./manage-model-rules.sh                   # Create custom models
EOF
}
show_models() {
    echo "Available models and aliases:"
    echo "  deepseek, ds  -> deepseek-coder:1.3b"
    echo "  qwen, q       -> qwen2.5-coder:1.5b"
    echo "  phi, phi3     -> phi3:mini"
    echo "  tiny, tinyllama -> tinyllama"
    echo "  codellama, cl -> codellama:7b"
    echo "  mistral, m    -> mistral:7b"
    echo ""
    echo "Currently pulled models:"
    ollama list 2>/dev/null || echo "  No models found or Ollama not running"
    echo ""
    echo "For custom models, run: ./manage-model-rules.sh"
}
handle_config() {
    case $1 in
        set)
            shift
            if [ "$#" -eq 1 ] && [[ "$1" =~ ^([0-9.]+):([0-9]+)$ ]]; then
                # Calls assign-target-ip-port.sh with IP:PORT format
                ~/assign-target-ip-port.sh "$1"
            elif [ "$#" -eq 2 ]; then
                # Calls assign-target-ip-port.sh with separate IP and PORT
                ~/assign-target-ip-port.sh "$1" "$2"
            else
                echo "Usage: $0 config set <ip:port>"
                echo "       $0 config set <ip> <port>"
            fi
            ;;
        show)
            # Shows config directly (doesn't call external script)
            if [ -f "$CONFIG_FILE" ]; then
                source "$CONFIG_FILE"
                if [ "$MASKED" = "true" ]; then
                    echo "Current target: $TARGET_IP_MASKED:$TARGET_PORT_MASKED (masked)"
                    echo "Run '$0 config mask off' to show actual values"
                else
                    echo "Current target: $TARGET_IP:$TARGET_PORT (unmasked)"
                    echo "Run '$0 config mask on' to mask"
                fi
            else
                echo "No target configuration found."
                echo "Run '$0 config set <ip:port>' to configure."
            fi
            ;;
        mask)
            # Calls toggle-target-mask.sh
            if [ "$2" = "on" ]; then
                ~/toggle-target-mask.sh on
            elif [ "$2" = "off" ]; then
                ~/toggle-target-mask.sh off
            else
                ~/toggle-target-mask.sh
            fi
            ;;
        test)
            # Tests connection directly (doesn't call external script)
            if [ -f "$CONFIG_FILE" ]; then
                source "$CONFIG_FILE"
                echo "Testing connection to $TARGET_IP:$TARGET_PORT..."
                if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 "http://${TARGET_IP}:${TARGET_PORT}/api/tags" 2>/dev/null | grep -q "200"; then
                    echo "✅ Connection successful"
                else
                    echo "❌ Connection failed"
                fi
            else
                echo "No target configuration found."
            fi
            ;;
        free-mem|freemem)
            if [ -f ~/free-mem-restart.sh ]; then
                ~/free-mem-restart.sh
            else
                echo "Running free memory command..."
                # Fallback if script doesn't exist
                sudo systemctl stop ollama
                sudo pkill -f ollama 2>/dev/null || true
                sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || true
                sudo systemctl start ollama
                echo "✅ Memory cleared and Ollama restarted"
            fi
            exit 0
            ;;
        *)
            show_help
            ;;
    esac
}

# ===== Main Argument Parsing =====
if [ "$#" -eq 0 ]; then
    show_help
    exit 0
fi

# Handle commands - ALL commands must exit before query handling
case $1 in
    help|-h|--help)
        show_help
        exit 0
        ;;
    config)
        shift
        handle_config "$@"
        exit 0  # MUST exit
        ;;
    models|list)
        show_models
        exit 0  # MUST exit
        ;;
    ps)
        ollama ps
        exit 0  # MUST exit
        ;;
    pull)
        if [ -n "$2" ]; then
            ollama pull "$2"
        else
            echo "Usage: $0 pull <model-name>"
        fi
        exit 0  # MUST exit
        ;;
    free-mem|freemem)
        if [ -f ~/free-mem-restart.sh ]; then
            ~/free-mem-restart.sh
        else
            echo "🧹 Freeing memory and restarting Ollama..."
            sudo systemctl stop ollama
            sudo pkill -f ollama 2>/dev/null || true
            sudo sync && echo 3 | sudo tee /proc/sys/vm/drop_caches > /dev/null 2>&1 || true
            sudo systemctl start ollama
            echo "✅ Memory cleared and Ollama restarted"
        fi
        exit 0  # MUST exit
        ;;
    host)
        AS_CLIENT=false
        ENDPOINT="http://localhost:11434/api/generate"
        echo "Switched to host mode (local)"
        # Continue to query handling - NO exit
        ;;
    client)
        if [ -f "$CONFIG_FILE" ]; then
            AS_CLIENT=true
            source "$CONFIG_FILE"
            ENDPOINT="http://${TARGET_IP}:${TARGET_PORT}/api/generate"
            if [ "$MASKED" = "true" ]; then
                echo "Switched to client mode -> $TARGET_IP_MASKED:$TARGET_PORT_MASKED"
            else
                echo "Switched to client mode -> $TARGET_IP:$TARGET_PORT"
            fi
            # Continue to query handling - NO exit
        else
            echo "No target configuration found. Run '$0 config set <ip:port>' first."
            exit 1
        fi
        ;;
esac

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
