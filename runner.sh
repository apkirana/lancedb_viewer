#!/bin/bash

# LanceDB Viewer Runner Script
# Usage: ./runner.sh [start|stop|restart|status]

PROJECT_DIR="/Users/puspa.kirana/Documents/GitHub/lancedb_viewer/lancedb-viewer"
BACKEND_DIR="$PROJECT_DIR/backend/src"
FRONTEND_DIR="$PROJECT_DIR/frontend"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Function to check if processes are running
check_status() {
    print_header "Checking Status"
    
    # Check backend
    if pgrep -f "uvicorn.*main:app.*8001" > /dev/null; then
        print_status "Backend is RUNNING (port 8001)"
    else
        print_warning "Backend is STOPPED"
    fi
    
    # Check frontend
    if pgrep -f "vite.*dev.*5173" > /dev/null; then
        print_status "Frontend is RUNNING (port 5173)"
    else
        print_warning "Frontend is STOPPED"
    fi
    
    echo ""
    echo "Process details:"
    ps aux | grep -E "(uvicorn.*main:app|vite.*dev)" | grep -v grep
}

# Function to stop all processes
stop_servers() {
    print_header "Stopping Servers"
    
    # Stop backend
    if pgrep -f "uvicorn.*main:app.*8001" > /dev/null; then
        print_status "Stopping backend..."
        pkill -f "uvicorn.*main:app.*8001"
        sleep 2
        print_status "Backend stopped"
    else
        print_warning "Backend was not running"
    fi
    
    # Stop frontend
    if pgrep -f "vite.*dev.*5173" > /dev/null; then
        print_status "Stopping frontend..."
        pkill -f "vite.*dev.*5173"
        sleep 2
        print_status "Frontend stopped"
    else
        print_warning "Frontend was not running"
    fi
    
    echo ""
    print_status "All servers stopped"
}

# Function to start both servers
start_servers() {
    print_header "Starting Servers"
    
    # Check if already running
    if pgrep -f "uvicorn.*main:app.*8001" > /dev/null; then
        print_warning "Backend is already running"
    else
        print_status "Starting backend..."
        cd "$BACKEND_DIR"
        python3 -m uvicorn main:app --host 0.0.0.0 --port 8001 --reload > /dev/null 2>&1 &
        sleep 3
        print_status "Backend started on port 8001"
    fi
    
    if pgrep -f "vite.*dev.*5173" > /dev/null; then
        print_warning "Frontend is already running"
    else
        print_status "Starting frontend..."
        cd "$FRONTEND_DIR"
        npm run dev > /dev/null 2>&1 &
        sleep 5
        print_status "Frontend started on port 5173"
    fi
    
    echo ""
    print_status "All servers started successfully!"
    echo ""
    print_status "Access your LanceDB Viewer at: http://localhost:5173"
    print_status "Backend API available at: http://localhost:8001"
}

# Function to restart servers
restart_servers() {
    print_header "Restarting Servers"
    stop_servers
    sleep 2
    start_servers
}

# Main script logic
case "$1" in
    start)
        start_servers
        ;;
    stop)
        stop_servers
        ;;
    restart)
        restart_servers
        ;;
    status)
        check_status
        ;;
    *)
        echo "LanceDB Viewer Runner Script"
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start both backend and frontend servers"
        echo "  stop    - Stop both servers"
        echo "  restart - Restart both servers"
        echo "  status  - Check running status of servers"
        echo ""
        echo "Example: $0 start"
        exit 1
        ;;
esac
