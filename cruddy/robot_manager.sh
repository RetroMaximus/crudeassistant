#!/bin/bash

# Cruddy Robot Service Manager
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROBOT_DIR="$SCRIPT_DIR"

start_robot() {
    echo "🤖 Starting Cruddy Robot..."
    cd "$ROBOT_DIR"
    source venv/bin/activate
    nohup python cruddy_control.py > robot.log 2>&1 &
    echo $! > robot.pid
    echo "✅ Cruddy started (PID: $(cat robot.pid))"
}

stop_robot() {
    echo "🛑 Stopping Cruddy Robot..."
    if [ -f "$ROBOT_DIR/robot.pid" ]; then
        kill $(cat "$ROBOT_DIR/robot.pid") 2>/dev/null || true
        rm -f "$ROBOT_DIR/robot.pid"
        echo "✅ Cruddy stopped"
    fi
}

status_robot() {
    if [ -f "$ROBOT_DIR/robot.pid" ] && kill -0 $(cat "$ROBOT_DIR/robot.pid") 2>/dev/null; then
        echo "✅ Cruddy: RUNNING (PID: $(cat "$ROBOT_DIR/robot.pid"))"
    else
        echo "❌ Cruddy: STOPPED"
    fi
}

case "$1" in
    start)
        start_robot
        ;;
    stop)
        stop_robot
        ;;
    restart)
        stop_robot
        sleep 2
        start_robot
        ;;
    status)
        status_robot
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
esac
