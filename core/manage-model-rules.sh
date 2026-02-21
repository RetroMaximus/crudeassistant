#!/bin/bash

# -----------------------------------------------------------------------------
# Ollama Custom Model Manager
# Create, edit, and manage custom models for your local LLM setup
# For Linux Mint with GTX 960M (optimized for memory constraints)
# -----------------------------------------------------------------------------

# Configuration
MODELS_DIR="$HOME/ollama-models"
TEMPLATES_DIR="$MODELS_DIR/templates"
CURRENT_MODELS=()

# Colours for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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

print_title() {
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
}

# Create necessary directories
setup_directories() {
    mkdir -p "$MODELS_DIR"
    mkdir -p "$TEMPLATES_DIR"
}

# Get list of available base models from Ollama
get_available_models() {
    # First check if Ollama is running
    if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
        print_warn "Ollama doesn't seem to be running or accessible"
        print_info "Starting Ollama..."
        systemctl --user start ollama 2>/dev/null || sudo systemctl start ollama 2>/dev/null
        sleep 3
    fi
    
    # Get models from Ollama
    MODELS_LIST=$(curl -s http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | cut -d'"' -f4)
    
    if [ -z "$MODELS_LIST" ]; then
        print_warn "No models found in Ollama. Please pull at least one model first."
        show_base_model_menu
    else
        # Convert to array
        IFS=$'\n' read -rd '' -a CURRENT_MODELS <<< "$MODELS_LIST"
    fi
}

# Show menu for base model selection
show_base_model_menu() {
    print_title "SELECT BASE MODEL"
    echo -e "Available lightweight models for coding:"
    echo ""
    echo -e "  ${GREEN}1)${NC} qwen2.5-coder:1.5b  (1.5B, good for autocomplete) [default]"
    echo -e "  ${GREEN}2)${NC} phi3:mini           (3.8B, more capable but heavier)"
    echo -e "  ${GREEN}3)${NC} deepseek-coder:1.3b (1.3B, coding specialised)"
    echo -e "  ${GREEN}4)${NC} tinyllama           (1.1B, very fast)"
    echo -e "  ${GREEN}5)${NC} codellama:7b        (7B, more capable - check VRAM)"
    echo -e "  ${GREEN}6)${NC} mistral:7b          (7B, general purpose)"
    echo -e "  ${GREEN}7)${NC} List all installed models"
    echo -e "  ${GREEN}8)${NC} Enter custom model name"
    echo ""
    read -p "Select model [1-8, default=1]: " model_choice

    case $model_choice in
        1) BASE_MODEL="qwen2.5-coder:1.5b" ;;
        2) BASE_MODEL="phi3:mini" ;;
        3) BASE_MODEL="deepseek-coder:1.3b" ;;
        4) BASE_MODEL="tinyllama" ;;
        5) BASE_MODEL="codellama:7b" ;;
        6) BASE_MODEL="mistral:7b" ;;
        7) 
            echo -e "Installed models:"
            curl -s http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | nl
            echo ""
            read -p "Enter the number of the model to use: " model_num
            SELECTED_MODEL=$(curl -s http://localhost:11434/api/tags | grep -o '"name":"[^"]*"' | cut -d'"' -f4 | sed -n "${model_num}p")
            if [ -n "$SELECTED_MODEL" ]; then
                BASE_MODEL="$SELECTED_MODEL"
            else
                print_error "Invalid selection"
                BASE_MODEL="qwen2.5-coder:1.5b"
            fi
            ;;
        8)
            read -p "Enter custom model name (e.g., llama2:7b): " BASE_MODEL
            ;;
        *) BASE_MODEL="qwen2.5-coder:1.5b" ;;
    esac
    
    print_info "Selected base model: $BASE_MODEL"
}

# Create a new custom model
create_custom_model() {
    print_title "CREATE CUSTOM MODEL"
    
    # Get model name
    read -p "Enter name for your custom model: " CUSTOM_NAME
    CUSTOM_NAME=$(echo "$CUSTOM_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
    
    if [ -z "$CUSTOM_NAME" ]; then
        print_error "Model name cannot be empty"
        return 1
    fi
    
    # Check if model already exists
    if ollama list 2>/dev/null | grep -q "$CUSTOM_NAME"; then
        print_warn "Model '$CUSTOM_NAME' already exists"
        read -p "Overwrite? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    # Select base model
    show_base_model_menu
    
    # Configure parameters
    print_step "Configure model parameters"
    echo -e "(Press Enter to accept defaults)"
    
    read -p "Temperature [0.1] (0.0-1.0): " TEMP
    TEMP=${TEMP:-0.1}
    
    read -p "Top P [0.9] (0.0-1.0): " TOP_P
    TOP_P=${TOP_P:-0.9}
    
    read -p "Top K [40] (1-100): " TOP_K
    TOP_K=${TOP_K:-40}
    
    read -p "Max tokens [2048]: " MAX_TOKENS
    MAX_TOKENS=${MAX_TOKENS:-2048}
    
    read -p "Context window size [4096]: " CONTEXT_SIZE
    CONTEXT_SIZE=${CONTEXT_SIZE:-4096}
    
    read -p "System prompt (e.g., 'You are a Python coding assistant'): " SYS_PROMPT
    if [ -z "$SYS_PROMPT" ]; then
        SYS_PROMPT="You are a helpful coding assistant focused on writing clean, efficient code."
    fi
    
    # Template selection
    echo ""
    echo -e "Available templates:"
    echo -e "  1) Python Coding Assistant"
    echo -e "  2) JavaScript/TypeScript Assistant"
    echo -e "  3) General Coding Assistant"
    echo -e "  4) DevOps/Scripting Assistant"
    echo -e "  5) Empty template (custom)"
    echo -e "  6) Load from file"
    echo ""
    read -p "Select template [1-6, default=1]: " template_choice
    
    MODELLE_FILE="$MODELS_DIR/${CUSTOM_NAME}.Modelfile"
    
    case $template_choice in
        2)
            cat > "$MODELLE_FILE" <<EOF
FROM $BASE_MODEL
PARAMETER temperature $TEMP
PARAMETER top_p $TOP_P
PARAMETER top_k $TOP_K
PARAMETER num_ctx $CONTEXT_SIZE
PARAMETER num_predict $MAX_TOKENS

SYSTEM """You are an expert JavaScript/TypeScript developer. You write clean, modern code using best practices.
Focus on:
- TypeScript best practices
- Modern ES6+ features
- React/Vue/Angular patterns when relevant
- Performance optimization
- Accessibility (a11y)
- Testing strategies"""
EOF
            ;;
        3)
            cat > "$MODELLE_FILE" <<EOF
FROM $BASE_MODEL
PARAMETER temperature $TEMP
PARAMETER top_p $TOP_P
PARAMETER top_k $TOP_K
PARAMETER num_ctx $CONTEXT_SIZE
PARAMETER num_predict $MAX_TOKENS

SYSTEM """You are a versatile programming assistant. You help with:
- Code writing and debugging
- Algorithm explanations
- Design patterns
- Code optimization
- Best practices across languages
- System design discussions"""
EOF
            ;;
        4)
            cat > "$MODELLE_FILE" <<EOF
FROM $BASE_MODEL
PARAMETER temperature $TEMP
PARAMETER top_p $TOP_P
PARAMETER top_k $TOP_K
PARAMETER num_ctx $CONTEXT_SIZE
PARAMETER num_predict $MAX_TOKENS

SYSTEM """You are a DevOps and scripting expert. You specialize in:
- Bash/PowerShell/Python scripting
- Docker and containerization
- CI/CD pipelines
- Cloud infrastructure (AWS/GCP/Azure)
- Kubernetes
- Infrastructure as Code (Terraform, CloudFormation)
- System administration"""
EOF
            ;;
        5)
            # Custom - just use basic system prompt
            cat > "$MODELLE_FILE" <<EOF
FROM $BASE_MODEL
PARAMETER temperature $TEMP
PARAMETER top_p $TOP_P
PARAMETER top_k $TOP_K
PARAMETER num_ctx $CONTEXT_SIZE
PARAMETER num_predict $MAX_TOKENS

SYSTEM "$SYS_PROMPT"
EOF
            ;;
        6)
            read -p "Enter path to Modelfile template: " template_path
            if [ -f "$template_path" ]; then
                cp "$template_path" "$MODELLE_FILE"
                print_info "Template loaded from $template_path"
            else
                print_error "File not found"
                return 1
            fi
            ;;
        *)
            # Default: Python Coding Assistant
            cat > "$MODELLE_FILE" <<EOF
FROM $BASE_MODEL
PARAMETER temperature $TEMP
PARAMETER top_p $TOP_P
PARAMETER top_k $TOP_K
PARAMETER num_ctx $CONTEXT_SIZE
PARAMETER num_predict $MAX_TOKENS

SYSTEM """You are an expert Python developer. You write clean, efficient, and well-documented Python code.
Follow these guidelines:
- Use type hints
- Follow PEP 8 style guide
- Write docstrings for functions and classes
- Handle exceptions appropriately
- Use list comprehensions when appropriate
- Prefer readability over cleverness
- Include examples in docstrings when helpful

You excel at:
- Data structures and algorithms
- Web frameworks (FastAPI, Django, Flask)
- Data science and machine learning
- Scripting and automation
- API development"""
EOF
            ;;
    esac
    
    print_info "Modelfile created at: $MODELLE_FILE"
    
    # Show Modelfile
    echo ""
    echo -e "Generated Modelfile content:"
    echo -e "─────────────────────────────"
    cat "$MODELLE_FILE"
    echo -e "─────────────────────────────"
    
    # Confirm creation
    read -p "Create this custom model? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_step "Creating custom model '$CUSTOM_NAME'..."
        ollama create "$CUSTOM_NAME" -f "$MODELLE_FILE"
        
        if [ $? -eq 0 ]; then
            print_info "✓ Model '$CUSTOM_NAME' created successfully!"
            
            # Save metadata
            cat > "$MODELS_DIR/${CUSTOM_NAME}.meta" <<EOF
NAME=$CUSTOM_NAME
BASE_MODEL=$BASE_MODEL
CREATED=$(date)
TEMPLATE=$template_choice
TEMP=$TEMP
TOP_P=$TOP_P
TOP_K=$TOP_K
CONTEXT=$CONTEXT_SIZE
MAX_TOKENS=$MAX_TOKENS
EOF
            
            # Generate usage example
            generate_usage_example "$CUSTOM_NAME"
        else
            print_error "Failed to create model"
        fi
    else
        print_info "Model creation cancelled"
        rm "$MODELLE_FILE"
    fi
}

# Generate usage example
generate_usage_example() {
    local model_name=$1
    local example_file="$MODELS_DIR/${model_name}_usage.txt"
    
    # Get server IP
    LOCAL_IP=$(ip route get 1 2>/dev/null | awk '{print $NF;exit}')
    if [ -z "$LOCAL_IP" ]; then
        LOCAL_IP="YOUR_SERVER_IP"
    fi
    
    cat > "$example_file" <<EOF
╔══════════════════════════════════════════════════════════════╗
║  Usage Examples for: $model_name
╚══════════════════════════════════════════════════════════════╝

1. LOCAL USAGE (on the server):
────────────────────────────────────────────────────────────────
ollama run $model_name

2. REMOTE USAGE (from another computer):
────────────────────────────────────────────────────────────────
curl http://$LOCAL_IP:11434/api/generate -d '{
  "model": "$model_name",
  "prompt": "write a Python function to calculate fibonacci",
  "stream": false
}'

3. WITH PARAMETERS:
────────────────────────────────────────────────────────────────
curl http://$LOCAL_IP:11434/api/generate -d '{
  "model": "$model_name",
  "prompt": "explain recursion",
  "temperature": 0.1,
  "max_tokens": 500,
  "stream": true
}'

4. CHAT COMPLETION API:
────────────────────────────────────────────────────────────────
curl http://$LOCAL_IP:11434/api/chat -d '{
  "model": "$model_name",
  "messages": [
    {"role": "user", "content": "write hello world in Python"}
  ]
}'

5. EMBEDDINGS:
────────────────────────────────────────────────────────────────
curl http://$LOCAL_IP:11434/api/embeddings -d '{
  "model": "$model_name",
  "prompt": "The quick brown fox jumps over the lazy dog"
}'

EOF
    
    print_info "Usage examples saved to: $example_file"
    
    echo ""
    echo -e "Quick test command:"
    echo -e "${GREEN}ollama run $model_name${NC}"
}

# List all custom models
list_models() {
    print_title "INSTALLED MODELS"
    
    echo -e "Base Models (from Ollama):"
    echo -e "────────────────────────────────────────────────────────────"
    ollama list 2>/dev/null | head -20
    echo ""
    
    echo -e "Custom Model Files (in $MODELS_DIR):"
    echo -e "────────────────────────────────────────────────────────────"
    if [ -d "$MODELS_DIR" ]; then
        find "$MODELS_DIR" -name "*.Modelfile" | while read f; do
            base=$(basename "$f" .Modelfile)
            if [ -f "$MODELS_DIR/${base}.meta" ]; then
                source "$MODELS_DIR/${base}.meta"
                echo -e "${GREEN}✓${NC} $base (from: $BASE_MODEL)"
            else
                echo -e "${YELLOW}?${NC} $base (no metadata)"
            fi
        done
    else
        echo -e "No custom models found"
    fi
    
    #echo ""
    #read -p "Press Enter to continue..." dummy
}

# Edit existing custom model
edit_model() {
    print_title "EDIT CUSTOM MODEL"
    
    # List available custom models
    echo -e "Available custom models:"
    echo -e "────────────────────────"
    models=()
    i=1
    if [ -d "$MODELS_DIR" ]; then
        for f in "$MODELS_DIR"/*.Modelfile; do
            if [ -f "$f" ]; then
                base=$(basename "$f" .Modelfile)
                models+=("$base")
                echo -e "  $i) $base"
                ((i++))
            fi
        done
    fi
    
    if [ ${#models[@]} -eq 0 ]; then
        print_warn "No custom models found"
        return 1
    fi
    
    echo ""
    read -p "Select model to edit (1-${#models[@]}): " model_idx
    
    if [ "$model_idx" -gt 0 ] && [ "$model_idx" -le "${#models[@]}" ]; then
        selected="${models[$((model_idx-1))]}"
        modelfile="$MODELS_DIR/${selected}.Modelfile"
        
        if [ -f "$modelfile" ]; then
            # Backup
            cp "$modelfile" "$modelfile.bak"
            
            # Edit
            ${EDITOR:-nano} "$modelfile"
            
            # Show diff
            if ! cmp -s "$modelfile" "$modelfile.bak"; then
                echo ""
                print_info "Changes detected"
                read -p "Update model '$selected' with these changes? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    ollama create "$selected" -f "$modelfile"
                    if [ $? -eq 0 ]; then
                        print_info "✓ Model updated successfully"
                        rm "$modelfile.bak"
                    else
                        print_error "Failed to update model"
                        mv "$modelfile.bak" "$modelfile"
                    fi
                else
                    mv "$modelfile.bak" "$modelfile"
                    print_info "Changes discarded"
                fi
            else
                print_info "No changes made"
                rm "$modelfile.bak"
            fi
        fi
    fi
}

# Delete custom model
delete_model() {
    print_title "DELETE CUSTOM MODEL"
    
    # List available custom models
    echo -e "Available custom models:"
    echo -e "────────────────────────"
    models=()
    i=1
    if [ -d "$MODELS_DIR" ]; then
        for f in "$MODELS_DIR"/*.Modelfile; do
            if [ -f "$f" ]; then
                base=$(basename "$f" .Modelfile)
                models+=("$base")
                echo -e "  $i) $base"
                ((i++))
            fi
        done
    fi
    
    if [ ${#models[@]} -eq 0 ]; then
        print_warn "No custom models found"
        return 1
    fi
    
    echo ""
    read -p "Select model to delete (1-${#models[@]}): " model_idx
    
    if [ "$model_idx" -gt 0 ] && [ "$model_idx" -le "${#models[@]}" ]; then
        selected="${models[$((model_idx-1))]}"
        
        echo ""
        print_warn "You are about to delete model: $selected"
        print_warn "This will remove the model from Ollama and delete its files"
        read -p "Are you absolutely sure? (type 'yes' to confirm): " confirm
        
        if [ "$confirm" = "yes" ]; then
            # Remove from Ollama
            ollama rm "$selected" 2>/dev/null
            
            # Remove files
            rm -f "$MODELS_DIR/${selected}.Modelfile"
            rm -f "$MODELS_DIR/${selected}.meta"
            rm -f "$MODELS_DIR/${selected}_usage.txt"
            
            print_info "✓ Model '$selected' deleted"
        else
            print_info "Deletion cancelled"
        fi
    fi
}

# Export model configuration
export_model() {
    print_title "EXPORT MODEL CONFIGURATION"
    
    # List available custom models
    echo -e "Available custom models:"
    echo -e "────────────────────────"
    models=()
    i=1
    if [ -d "$MODELS_DIR" ]; then
        for f in "$MODELS_DIR"/*.Modelfile; do
            if [ -f "$f" ]; then
                base=$(basename "$f" .Modelfile)
                models+=("$base")
                echo -e "  $i) $base"
                ((i++))
            fi
        done
    fi
    
    if [ ${#models[@]} -eq 0 ]; then
        print_warn "No custom models found"
        return 1
    fi
    
    echo ""
    read -p "Select model to export (1-${#models[@]}): " model_idx
    
    if [ "$model_idx" -gt 0 ] && [ "$model_idx" -le "${#models[@]}" ]; then
        selected="${models[$((model_idx-1))]}"
        
        export_file="$HOME/${selected}_export.tar.gz"
        tar -czf "$export_file" -C "$MODELS_DIR" "${selected}.Modelfile" "${selected}.meta" 2>/dev/null
        
        if [ $? -eq 0 ]; then
            print_info "✓ Model exported to: $export_file"
            echo ""
            echo -e "To import on another machine:"
            echo -e "  tar -xzf $export_file -C ~/ollama-models/"
            echo -e "  ollama create $selected -f ~/ollama-models/${selected}.Modelfile"
        else
            print_error "Export failed"
        fi
    fi
}

# Test model
test_model() {
    print_title "TEST MODEL"
    
    # List available models (both base and custom)
    echo -e "Available models:"
    echo -e "────────────────"
    i=1
    declare -a all_models
    
    # Get Ollama models
    while IFS= read -r model; do
        if [ -n "$model" ]; then
            echo -e "  $i) $model (base)"
            all_models+=("$model")
            ((i++))
        fi
    done < <(ollama list 2>/dev/null | tail -n +2 | awk '{print $1}')
    
    if [ ${#all_models[@]} -eq 0 ]; then
        print_error "No models found"
        return 1
    fi
    
    echo ""
    read -p "Select model to test (1-${#all_models[@]}): " model_idx
    
    if [ "$model_idx" -gt 0 ] && [ "$model_idx" -le "${#all_models[@]}" ]; then
        selected="${all_models[$((model_idx-1))]}"
        
        echo ""
        echo -e "Select test prompt:"
        echo -e "  1) Write a Python function to check if a number is prime"
        echo -e "  2) Explain recursion with an example"
        echo -e "  3) Write a bash script to backup a directory"
        echo -e "  4) Custom prompt"
        echo ""
        read -p "Choose test [1-4]: " test_choice
        
        case $test_choice in
            1) prompt="Write a Python function to check if a number is prime. Include type hints and docstring." ;;
            2) prompt="Explain recursion with a simple example in JavaScript." ;;
            3) prompt="Write a bash script to backup a directory with timestamp and compression." ;;
            4) 
                read -p "Enter your test prompt: " prompt
                ;;
            *) prompt="Write hello world in Python" ;;
        esac
        
        echo ""
        print_info "Testing model: $selected"
        print_info "Prompt: $prompt"
        echo -e "────────────────────────────────────────────────────────────"
        
        # Run the model
        ollama run "$selected" "$prompt"
        
        echo -e "────────────────────────────────────────────────────────────"
    fi
}

# Show main menu
show_menu() {
    clear
    print_title "OLLAMA CUSTOM MODEL MANAGER"
    echo -e "  ${GREEN}1)${NC} Create new custom model"
    echo -e "  ${GREEN}2)${NC} List all models"
    echo -e "  ${GREEN}3)${NC} Edit existing custom model"
    echo -e "  ${GREEN}4)${NC} Delete custom model"
    echo -e "  ${GREEN}5)${NC} Export model configuration"
    echo -e "  ${GREEN}6)${NC} Test a model"
    echo -e "  ${GREEN}7)${NC} Show usage examples"
    echo -e "  ${GREEN}8)${NC} Exit"
    echo ""
    
    # Get memory info
    MEM_INFO=$(free -h | grep Mem | awk '{print $3"/"$2}')
    echo -e "  ${YELLOW}Memory Info:${NC} $MEM_INFO used"
    
    # Get GPU info if available
    if command -v nvidia-smi &> /dev/null; then
        GPU_MEM=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>/dev/null | head -1)
        if [ -n "$GPU_MEM" ]; then
            echo -e "  ${YELLOW}GPU VRAM:${NC} $GPU_MEM MB used"
        else
            echo -e "  ${YELLOW}GPU VRAM:${NC} N/A"
        fi
    fi
    
    echo ""
    read -p "Select option [1-8]: " menu_choice
}

# Show usage examples
show_usage() {
    print_title "USAGE EXAMPLES"
    
    echo -e "QUICK REFERENCE"
    echo -e "────────────────────────────────────────────────────────────"
    echo ""
    echo -e "1. RUN A MODEL INTERACTIVELY:"
    echo -e "   ollama run <model-name>"
    echo ""
    echo -e "2. ONE-SHOT PROMPT:"
    echo -e "   ollama run <model-name> 'your prompt here'"
    echo ""
    echo -e "3. API CALL (from another computer):"
    echo -e "   curl http://<server-ip>:11434/api/generate -d '{"
    echo -e '     "model": "<model-name>",'
    echo -e '     "prompt": "your prompt",'
    echo -e '     "stream": false'
    echo -e "   }'"
    echo ""
    echo -e "4. LIST ALL MODELS:"
    echo -e "   ollama list"
    echo ""
    echo -e "5. SHOW MODEL INFO:"
    echo -e "   ollama show <model-name>"
    echo ""
    echo -e "6. REMOVE A MODEL:"
    echo -e "   ollama rm <model-name>"
    echo ""
    
    # Get server IP
    LOCAL_IP=$(ip route get 1 2>/dev/null | awk '{print $NF;exit}')
    if [ -n "$LOCAL_IP" ]; then
        echo -e "YOUR SERVER IP: $LOCAL_IP"
    fi
    
    #echo ""
    #read -p "Press Enter to continue..."
}

# Main execution
main() {
    # Check if Ollama is installed
    if ! command -v ollama &> /dev/null; then
        print_error "Ollama is not installed. Please install it first."
        exit 1
    fi
    
    # Setup directories
    setup_directories
    
    # Main loop
    while true; do
        show_menu
        
        case $menu_choice in
            1)
                create_custom_model
                ;;
            2)
                list_models
                ;;
            3)
                edit_model
                ;;
            4)
                delete_model
                ;;
            5)
                export_model
                ;;
            6)
                test_model
                ;;
            7)
                show_usage
                ;;
            8)
                print_info "Exiting"
                exit 0
                ;;
            *)
                print_error "Invalid option"
                sleep 2
                ;;
        esac
        
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Run main function
main
