#!/bin/bash

# AI Assistant Service Manager
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DIR="$SCRIPT_DIR/.."

start_service() {
    echo "🚀 Starting AI Assistant services..."
    
    # Start Ollama if not running
    if ! systemctl is-active --quiet ollama; then
        sudo systemctl start ollama
        echo "✅ Ollama service started"
    else
        echo "✅ Ollama service already running"
    fi
    
    # Start API server
    cd "$AI_DIR"
    source venv/bin/activate
    nohup python scripts/api_server.py > logs/api_server.log 2>&1 &
    echo $! > logs/api_server.pid
    echo "✅ API server started (PID: $(cat logs/api_server.pid))"
    
    echo "🌐 API server available at: http://$(curl -s ifconfig.me):8000"
}

stop_service() {
    echo "🛑 Stopping AI Assistant services..."
    
    # Stop API server
    if [ -f "$AI_DIR/logs/api_server.pid" ]; then
        kill $(cat "$AI_DIR/logs/api_server.pid") 2>/dev/null || true
        rm -f "$AI_DIR/logs/api_server.pid"
        echo "✅ API server stopped"
    fi
    
    # Optional: stop Ollama (comment out if you want it running always)
    # sudo systemctl stop ollama
    # echo "✅ Ollama service stopped"
}

restart_service() {
    stop_service
    sleep 2
    start_service
}

status_service() {
    echo "📊 Service Status:"
    echo "================="
    
    # Check Ollama
    if systemctl is-active --quiet ollama; then
        echo "✅ Ollama: RUNNING"
    else
        echo "❌ Ollama: STOPPED"
    fi
    
    # Check API server
    if [ -f "$AI_DIR/logs/api_server.pid" ] && kill -0 $(cat "$AI_DIR/logs/api_server.pid") 2>/dev/null; then
        echo "✅ API Server: RUNNING (PID: $(cat "$AI_DIR/logs/api_server.pid"))"
    else
        echo "❌ API Server: STOPPED"
    fi
}

case "$1" in
    start)
        start_service
        ;;
    stop)
        stop_service
        ;;
    restart)
        restart_service
        ;;
    status)
        status_service
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
