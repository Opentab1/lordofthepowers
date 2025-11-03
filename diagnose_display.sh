#!/bin/bash
# Pulse Display Loading Diagnostic Script
# This script helps diagnose why the display/dashboard isn't loading

set -e

echo "═══════════════════════════════════════════════════════════"
echo "  Pulse Display Loading Diagnostics"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if we're on the Pi or development machine
IS_PI=false
if [ -f "/opt/pulse/config/config.yaml" ]; then
    IS_PI=true
fi

echo -e "${BLUE}[1/8] Checking wizard completion status...${NC}"
echo "─────────────────────────────────────────────────────────────"
if [ "$IS_PI" = true ]; then
    if [ -f "/opt/pulse/config/.wizard_complete" ]; then
        echo -e "${GREEN}✓ Wizard completion marker found${NC}"
        echo "  Location: /opt/pulse/config/.wizard_complete"
    else
        echo -e "${YELLOW}⚠ Wizard completion marker NOT found${NC}"
        echo "  Expected: /opt/pulse/config/.wizard_complete"
        echo "  This means first-boot wizard should be running"
    fi
else
    echo -e "${YELLOW}⚠ Not running on Pi (no /opt/pulse directory)${NC}"
fi
echo ""

echo -e "${BLUE}[2/8] Checking service status...${NC}"
echo "─────────────────────────────────────────────────────────────"
if command -v systemctl &> /dev/null; then
    # Check firstboot service
    if systemctl list-unit-files | grep -q "pulse-firstboot.service"; then
        FIRSTBOOT_STATUS=$(systemctl is-active pulse-firstboot.service 2>/dev/null || echo "inactive")
        FIRSTBOOT_ENABLED=$(systemctl is-enabled pulse-firstboot.service 2>/dev/null || echo "disabled")
        
        if [ "$FIRSTBOOT_STATUS" = "active" ]; then
            echo -e "${GREEN}✓ pulse-firstboot (wizard): $FIRSTBOOT_STATUS ($FIRSTBOOT_ENABLED)${NC}"
        else
            echo -e "${YELLOW}○ pulse-firstboot (wizard): $FIRSTBOOT_STATUS ($FIRSTBOOT_ENABLED)${NC}"
        fi
    fi
    
    # Check hub service
    if systemctl list-unit-files | grep -q "pulse-hub.service"; then
        HUB_STATUS=$(systemctl is-active pulse-hub.service 2>/dev/null || echo "inactive")
        HUB_ENABLED=$(systemctl is-enabled pulse-hub.service 2>/dev/null || echo "disabled")
        
        if [ "$HUB_STATUS" = "active" ]; then
            echo -e "${GREEN}✓ pulse-hub (backend): $HUB_STATUS ($HUB_ENABLED)${NC}"
        else
            echo -e "${RED}✗ pulse-hub (backend): $HUB_STATUS ($HUB_ENABLED)${NC}"
        fi
    fi
    
    # Check dashboard service
    if systemctl list-unit-files | grep -q "pulse-dashboard.service"; then
        DASH_STATUS=$(systemctl is-active pulse-dashboard.service 2>/dev/null || echo "inactive")
        DASH_ENABLED=$(systemctl is-enabled pulse-dashboard.service 2>/dev/null || echo "disabled")
        
        if [ "$DASH_STATUS" = "active" ]; then
            echo -e "${GREEN}✓ pulse-dashboard (frontend): $DASH_STATUS ($DASH_ENABLED)${NC}"
        else
            echo -e "${RED}✗ pulse-dashboard (frontend): $DASH_STATUS ($DASH_ENABLED)${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠ systemctl not available${NC}"
fi
echo ""

echo -e "${BLUE}[3/8] Checking port availability...${NC}"
echo "─────────────────────────────────────────────────────────────"
# Check if ports are listening
check_port() {
    local port=$1
    local service=$2
    if command -v ss &> /dev/null; then
        if ss -tlnp 2>/dev/null | grep -q ":$port "; then
            echo -e "${GREEN}✓ Port $port ($service): LISTENING${NC}"
            return 0
        else
            echo -e "${RED}✗ Port $port ($service): NOT listening${NC}"
            return 1
        fi
    elif command -v netstat &> /dev/null; then
        if netstat -tln 2>/dev/null | grep -q ":$port "; then
            echo -e "${GREEN}✓ Port $port ($service): LISTENING${NC}"
            return 0
        else
            echo -e "${RED}✗ Port $port ($service): NOT listening${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠ Cannot check ports (ss/netstat not available)${NC}"
        return 2
    fi
}

check_port 9090 "Wizard"
check_port 8080 "Dashboard"
check_port 7000 "Hub API"
check_port 9977 "Kiosk Fallback"
echo ""

echo -e "${BLUE}[4/8] Testing HTTP connectivity...${NC}"
echo "─────────────────────────────────────────────────────────────"
test_url() {
    local url=$1
    local name=$2
    if command -v curl &> /dev/null; then
        if curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 "$url" | grep -q "200\|301\|302"; then
            echo -e "${GREEN}✓ $name: Accessible${NC}"
            echo "  URL: $url"
        else
            echo -e "${RED}✗ $name: Not accessible${NC}"
            echo "  URL: $url"
        fi
    else
        echo -e "${YELLOW}⚠ Cannot test URLs (curl not available)${NC}"
    fi
}

test_url "http://localhost:9090" "Wizard"
test_url "http://localhost:8080" "Dashboard"
test_url "http://localhost:7000/health" "Hub API"
test_url "http://localhost:9977" "Kiosk Fallback"
echo ""

echo -e "${BLUE}[5/8] Checking file structure...${NC}"
echo "─────────────────────────────────────────────────────────────"
if [ "$IS_PI" = true ]; then
    check_path() {
        local path=$1
        local name=$2
        if [ -e "$path" ]; then
            echo -e "${GREEN}✓ $name exists${NC}"
            echo "  Path: $path"
        else
            echo -e "${RED}✗ $name missing${NC}"
            echo "  Expected: $path"
        fi
    }
    
    check_path "/opt/pulse/dashboard/server/server.js" "Dashboard server"
    check_path "/opt/pulse/dashboard/ui/dist" "Dashboard UI build"
    check_path "/opt/pulse/services/hub/main.py" "Hub main"
    check_path "/opt/pulse/bootstrap/wizard/server.py" "Wizard server"
    check_path "/opt/pulse/config/config.yaml" "Config file"
else
    echo -e "${YELLOW}⚠ Skipping file check (not on Pi)${NC}"
fi
echo ""

echo -e "${BLUE}[6/8] Checking recent logs...${NC}"
echo "─────────────────────────────────────────────────────────────"
if [ "$IS_PI" = true ] && [ -d "/var/log/pulse" ]; then
    echo "Last 5 lines from key logs:"
    echo ""
    
    if [ -f "/var/log/pulse/firstboot.err" ]; then
        echo "  firstboot.err:"
        tail -n 5 /var/log/pulse/firstboot.err 2>/dev/null | sed 's/^/    /'
        echo ""
    fi
    
    if [ -f "/var/log/pulse/dashboard.err" ]; then
        echo "  dashboard.err:"
        tail -n 5 /var/log/pulse/dashboard.err 2>/dev/null | sed 's/^/    /'
        echo ""
    fi
    
    if [ -f "/var/log/pulse/hub.err" ]; then
        echo "  hub.err:"
        tail -n 5 /var/log/pulse/hub.err 2>/dev/null | sed 's/^/    /'
        echo ""
    fi
else
    echo -e "${YELLOW}⚠ Log directory not found${NC}"
fi
echo ""

echo -e "${BLUE}[7/8] Checking browser/display...${NC}"
echo "─────────────────────────────────────────────────────────────"
if pgrep -x "chromium" > /dev/null || pgrep -x "chromium-browser" > /dev/null; then
    echo -e "${GREEN}✓ Chromium is running${NC}"
    CHROMIUM_PID=$(pgrep -x "chromium" || pgrep -x "chromium-browser" | head -1)
    echo "  PID: $CHROMIUM_PID"
else
    echo -e "${YELLOW}⚠ Chromium is NOT running${NC}"
fi
echo ""

echo -e "${BLUE}[8/8] System recommendations...${NC}"
echo "─────────────────────────────────────────────────────────────"

# Determine what the user should do
WIZARD_EXISTS=false
WIZARD_RUNNING=false
DASHBOARD_RUNNING=false

if [ -f "/opt/pulse/config/.wizard_complete" ]; then
    WIZARD_EXISTS=true
fi

if [ "$IS_PI" = true ] && command -v systemctl &> /dev/null; then
    if systemctl is-active pulse-firstboot.service 2>/dev/null | grep -q "active"; then
        WIZARD_RUNNING=true
    fi
    if systemctl is-active pulse-dashboard.service 2>/dev/null | grep -q "active"; then
        DASHBOARD_RUNNING=true
    fi
fi

echo ""
if [ "$WIZARD_EXISTS" = false ]; then
    echo -e "${YELLOW}📋 First-time setup detected${NC}"
    echo ""
    echo "You should see the Setup Wizard at:"
    echo -e "  ${GREEN}http://localhost:9090${NC}"
    echo ""
    if [ "$WIZARD_RUNNING" = false ]; then
        echo -e "${RED}But the wizard service is NOT running!${NC}"
        echo ""
        echo "Quick fix:"
        echo "  sudo systemctl start pulse-firstboot.service"
        echo "  # Wait 10 seconds, then open: http://localhost:9090"
    fi
elif [ "$DASHBOARD_RUNNING" = false ]; then
    echo -e "${YELLOW}📋 Wizard complete, but dashboard not running${NC}"
    echo ""
    echo "Quick fix:"
    echo "  sudo systemctl start pulse-hub.service"
    echo "  sudo systemctl start pulse-dashboard.service"
    echo "  # Wait 15 seconds, then open: http://localhost:8080"
else
    echo -e "${GREEN}📋 Everything looks good!${NC}"
    echo ""
    echo "Dashboard should be available at:"
    echo -e "  ${GREEN}http://localhost:8080${NC}"
    echo ""
    echo "If you're seeing a white screen:"
    echo "  1. Press ESC to exit fullscreen"
    echo "  2. Navigate to http://localhost:8080 manually"
    echo "  3. Or restart the kiosk:"
    echo "     pkill chromium"
    echo "     export DISPLAY=:0"
    echo "     /opt/pulse/dashboard/kiosk/start.sh"
fi

echo ""
echo -e "${BLUE}Need more help?${NC}"
echo "  • View full logs: tail -f /var/log/pulse/*.log"
echo "  • Restart services: sudo systemctl restart pulse-*"
echo "  • Check troubleshooting guide: /opt/pulse/TROUBLESHOOTING.md"
echo ""
echo "═══════════════════════════════════════════════════════════"
