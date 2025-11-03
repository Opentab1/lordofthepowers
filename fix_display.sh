#!/bin/bash
# Pulse Display Quick Fix Script
# Automatically fixes common display loading issues

set -e

echo "═══════════════════════════════════════════════════════════"
echo "  Pulse Display Quick Fix"
echo "═══════════════════════════════════════════════════════════"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}Please run with sudo:${NC}"
    echo "  sudo $0"
    exit 1
fi

# Check if we're on the Pi
if [ ! -d "/opt/pulse" ]; then
    echo -e "${RED}Error: /opt/pulse directory not found${NC}"
    echo "This script should only run on an installed Pulse system."
    exit 1
fi

echo -e "${BLUE}[1/5] Stopping all Pulse services...${NC}"
systemctl stop pulse-*.service 2>/dev/null || true
echo -e "${GREEN}✓ Services stopped${NC}"
echo ""

echo -e "${BLUE}[2/5] Checking wizard completion status...${NC}"
if [ -f "/opt/pulse/config/.wizard_complete" ]; then
    echo -e "${GREEN}✓ Wizard marked as complete${NC}"
    WIZARD_COMPLETE=true
else
    echo -e "${YELLOW}○ Wizard not complete - will start wizard${NC}"
    WIZARD_COMPLETE=false
fi
echo ""

echo -e "${BLUE}[3/5] Updating service configurations...${NC}"
# Ensure the dashboard service has correct paths
DASHBOARD_SERVICE="/etc/systemd/system/pulse-dashboard.service"
if [ -f "$DASHBOARD_SERVICE" ]; then
    # Update WorkingDirectory if it's wrong
    if grep -q "WorkingDirectory=/opt/pulse/dashboard/api" "$DASHBOARD_SERVICE"; then
        echo "  Fixing dashboard service working directory..."
        sed -i 's|WorkingDirectory=/opt/pulse/dashboard/api|WorkingDirectory=/opt/pulse/dashboard/server|g' "$DASHBOARD_SERVICE"
        sed -i 's|ExecStart=/usr/bin/npm start --silent|ExecStart=/usr/bin/node server.js|g' "$DASHBOARD_SERVICE"
        echo -e "${GREEN}  ✓ Dashboard service updated${NC}"
    else
        echo -e "${GREEN}  ✓ Dashboard service already correct${NC}"
    fi
fi

# Ensure firstboot service has correct marker path
FIRSTBOOT_SERVICE="/etc/systemd/system/pulse-firstboot.service"
if [ -f "$FIRSTBOOT_SERVICE" ]; then
    if grep -q "ConditionPathExists=!/opt/pulse/.setup_done" "$FIRSTBOOT_SERVICE"; then
        echo "  Fixing firstboot service marker path..."
        sed -i 's|ConditionPathExists=!/opt/pulse/.setup_done|ConditionPathExists=!/opt/pulse/config/.wizard_complete|g' "$FIRSTBOOT_SERVICE"
        echo -e "${GREEN}  ✓ Firstboot service updated${NC}"
    else
        echo -e "${GREEN}  ✓ Firstboot service already correct${NC}"
    fi
fi

# Reload systemd
systemctl daemon-reload
echo -e "${GREEN}✓ Systemd configuration reloaded${NC}"
echo ""

echo -e "${BLUE}[4/5] Starting appropriate services...${NC}"
if [ "$WIZARD_COMPLETE" = true ]; then
    echo "  Starting hub and dashboard services..."
    systemctl start pulse-hub.service
    sleep 2
    systemctl start pulse-dashboard.service
    
    echo -e "${GREEN}✓ Hub and Dashboard services started${NC}"
    echo ""
    echo -e "${GREEN}Dashboard should be available at:${NC}"
    echo -e "  ${YELLOW}http://localhost:8080${NC}"
else
    echo "  Starting wizard service..."
    systemctl start pulse-firstboot.service
    
    echo -e "${GREEN}✓ Wizard service started${NC}"
    echo ""
    echo -e "${GREEN}Wizard should be available at:${NC}"
    echo -e "  ${YELLOW}http://localhost:9090${NC}"
fi
echo ""

echo -e "${BLUE}[5/5] Restarting kiosk browser...${NC}"
# Kill any existing Chromium instances
pkill chromium 2>/dev/null || true
pkill chromium-browser 2>/dev/null || true
sleep 1

# Restart kiosk if DISPLAY is set
if [ -n "${DISPLAY}" ]; then
    echo "  Starting kiosk browser..."
    if [ -f "/opt/pulse/dashboard/kiosk/start.sh" ]; then
        su - pi -c "DISPLAY=:0 /opt/pulse/dashboard/kiosk/start.sh" &
        echo -e "${GREEN}✓ Kiosk browser restarted${NC}"
    else
        echo -e "${YELLOW}⚠ Kiosk script not found${NC}"
    fi
else
    echo -e "${YELLOW}⚠ DISPLAY not set - run manually:${NC}"
    echo "  export DISPLAY=:0"
    echo "  /opt/pulse/dashboard/kiosk/start.sh"
fi
echo ""

echo "═══════════════════════════════════════════════════════════"
echo -e "${GREEN}Fix complete!${NC}"
echo ""
echo "What to expect:"
if [ "$WIZARD_COMPLETE" = true ]; then
    echo "  • Wait 10-15 seconds for services to start"
    echo "  • Browser should open to dashboard (port 8080)"
    echo "  • If you see white screen, press ESC and go to http://localhost:8080"
else
    echo "  • Wait 10-15 seconds for wizard to start"
    echo "  • Browser should open to wizard (port 9090)"
    echo "  • Complete the wizard to enable full system"
fi
echo ""
echo "Still having issues?"
echo "  • Run diagnostics: /opt/pulse/diagnose_display.sh"
echo "  • Check logs: tail -f /var/log/pulse/*.log"
echo "  • Check status: sudo systemctl status pulse-*"
echo ""
echo "═══════════════════════════════════════════════════════════"
