#!/bin/bash

# LanceDB Viewer Runner Script
# Usage: ./runner.sh [start|stop|restart|status]
# Running with no arguments defaults to: start

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$PROJECT_DIR/backend/src"
FRONTEND_DIR="$PROJECT_DIR/frontend"
LOG_DIR="$PROJECT_DIR/.logs"

BACKEND_LOG="$LOG_DIR/backend.log"
FRONTEND_LOG="$LOG_DIR/frontend.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status()  { echo -e "${GREEN}[INFO]${NC}  $1"; }
print_error()   { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC}  $1"; }
print_header()  { echo -e "\n${BLUE}╔══════════════════════════════╗${NC}"; \
                  echo -e "${BLUE}║  $1${NC}"; \
                  echo -e "${BLUE}╚══════════════════════════════╝${NC}"; }

# ── Helpers ────────────────────────────────────────────────────────────────────

is_backend_running() {
    pgrep -f "uvicorn.*main:app" > /dev/null 2>&1
}

is_frontend_running() {
    pgrep -f "vite" > /dev/null 2>&1
}

get_frontend_port() {
    # Read the port vite actually bound to from its log
    grep -o "localhost:[0-9]*" "$FRONTEND_LOG" 2>/dev/null | head -1 | cut -d: -f2
}

wait_for_port() {
    local port=$1
    local timeout=$2
    local elapsed=0
    while ! lsof -i ":$port" > /dev/null 2>&1; do
        sleep 1
        elapsed=$((elapsed + 1))
        if [ "$elapsed" -ge "$timeout" ]; then
            return 1
        fi
    done
    return 0
}

# ── Stop ───────────────────────────────────────────────────────────────────────

stop_servers() {
    print_header "Stopping Servers          "

    if is_backend_running; then
        print_status "Stopping backend..."
        pkill -f "uvicorn.*main:app" && sleep 1
        print_status "Backend stopped."
    else
        print_warning "Backend was not running."
    fi

    if is_frontend_running; then
        print_status "Stopping frontend..."
        pkill -f "vite" && sleep 1
        print_status "Frontend stopped."
    else
        print_warning "Frontend was not running."
    fi

    echo ""
    print_status "All servers stopped."
}

# ── Start ──────────────────────────────────────────────────────────────────────

start_servers() {
    print_header "Starting LanceDB Viewer   "

    mkdir -p "$LOG_DIR"

    # ── Backend ──────────────────────────────────────────────────────────────
    if is_backend_running; then
        print_warning "Backend is already running — skipping."
    else
        print_status "Starting backend  →  http://localhost:8001"

        cd "$BACKEND_DIR" || { print_error "Cannot find backend dir: $BACKEND_DIR"; exit 1; }

        # Use uv if available, fall back to python3
        if command -v uv > /dev/null 2>&1; then
            uv run uvicorn main:app --host 0.0.0.0 --port 8001 --reload \
                > "$BACKEND_LOG" 2>&1 &
        else
            python3 -m uvicorn main:app --host 0.0.0.0 --port 8001 --reload \
                > "$BACKEND_LOG" 2>&1 &
        fi

        # Wait up to 10 s for port 8001
        if wait_for_port 8001 10; then
            print_status "Backend is UP  ✓"
        else
            print_error "Backend did not start within 10 s. Check logs: $BACKEND_LOG"
            tail -20 "$BACKEND_LOG"
            exit 1
        fi
    fi

    # ── Frontend ─────────────────────────────────────────────────────────────
    if is_frontend_running; then
        print_warning "Frontend is already running — skipping."
    else
        print_status "Starting frontend..."

        cd "$FRONTEND_DIR" || { print_error "Cannot find frontend dir: $FRONTEND_DIR"; exit 1; }

        npm run dev > "$FRONTEND_LOG" 2>&1 &

        # Wait up to 20 s for vite to bind a port
        local attempts=0
        local fe_port=""
        while [ -z "$fe_port" ] && [ "$attempts" -lt 20 ]; do
            sleep 1
            fe_port=$(get_frontend_port)
            attempts=$((attempts + 1))
        done

        if [ -n "$fe_port" ]; then
            print_status "Frontend is UP ✓  →  http://localhost:$fe_port"
        else
            print_error "Frontend did not start within 20 s. Check logs: $FRONTEND_LOG"
            tail -20 "$FRONTEND_LOG"
            exit 1
        fi
    fi

    echo ""
    echo -e "  ${CYAN}🚀  Open in browser:${NC}  http://localhost:$(get_frontend_port)"
    echo -e "  ${CYAN}📡  Backend API:${NC}      http://localhost:8001"
    echo -e "  ${CYAN}📋  Logs:${NC}             $LOG_DIR/"
    echo ""
}

# ── Status ─────────────────────────────────────────────────────────────────────

check_status() {
    print_header "Server Status             "

    if is_backend_running; then
        print_status "Backend   →  RUNNING  (http://localhost:8001)"
    else
        print_warning "Backend   →  STOPPED"
    fi

    if is_frontend_running; then
        local fe_port
        fe_port=$(get_frontend_port)
        if [ -n "$fe_port" ]; then
            print_status "Frontend  →  RUNNING  (http://localhost:$fe_port)"
        else
            print_status "Frontend  →  RUNNING  (port unknown — check $FRONTEND_LOG)"
        fi
    else
        print_warning "Frontend  →  STOPPED"
    fi

    echo ""
    echo "Logs: $LOG_DIR/"
}

# ── Restart ────────────────────────────────────────────────────────────────────

restart_servers() {
    stop_servers
    sleep 1
    start_servers
}

# ── Main ───────────────────────────────────────────────────────────────────────

# Default to "start" if no argument given
COMMAND="${1:-start}"

case "$COMMAND" in
    start)   start_servers ;;
    stop)    stop_servers ;;
    restart) restart_servers ;;
    status)  check_status ;;
    *)
        echo "Usage: $0 [start|stop|restart|status]"
        echo "  (no argument defaults to: start)"
        exit 1
        ;;
esac
