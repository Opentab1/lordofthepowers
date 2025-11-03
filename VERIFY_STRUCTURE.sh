#!/bin/bash
# Verify Pulse Installation Structure

echo "=========================================="
echo "Pulse Installation Structure Verification"
echo "=========================================="
echo ""

ERRORS=0

# Check dashboard structure
echo "✓ Checking dashboard structure..."
[ -d "dashboard/ui" ] || { echo "  ✗ Missing dashboard/ui"; ERRORS=$((ERRORS+1)); }
[ -f "dashboard/ui/package.json" ] || { echo "  ✗ Missing dashboard/ui/package.json"; ERRORS=$((ERRORS+1)); }
[ -d "dashboard/ui/src" ] || { echo "  ✗ Missing dashboard/ui/src"; ERRORS=$((ERRORS+1)); }
[ -f "dashboard/ui/src/main.tsx" ] || [ -f "dashboard/ui/src/main.jsx" ] || { echo "  ✗ Missing main entry point"; ERRORS=$((ERRORS+1)); }
[ -d "dashboard/kiosk" ] || { echo "  ✗ Missing dashboard/kiosk"; ERRORS=$((ERRORS+1)); }
[ -f "dashboard/kiosk/start.sh" ] || { echo "  ✗ Missing kiosk start script"; ERRORS=$((ERRORS+1)); }
[ -f "dashboard/kiosk/index.html" ] || { echo "  ✗ Missing kiosk fallback page"; ERRORS=$((ERRORS+1)); }

# Check services structure
echo "✓ Checking services structure..."
[ -d "services/hub" ] || { echo "  ✗ Missing services/hub"; ERRORS=$((ERRORS+1)); }
[ -f "services/hub/main.py" ] || { echo "  ✗ Missing services/hub/main.py"; ERRORS=$((ERRORS+1)); }
[ -f "services/hub/run_pulse_system.py" ] || { echo "  ✗ Missing run_pulse_system.py"; ERRORS=$((ERRORS+1)); }
[ -d "services/sensors" ] || { echo "  ✗ Missing services/sensors"; ERRORS=$((ERRORS+1)); }
[ -f "services/sensors/health_monitor.py" ] || { echo "  ✗ Missing health_monitor.py"; ERRORS=$((ERRORS+1)); }
[ -d "services/integrations" ] || { echo "  ✗ Missing services/integrations"; ERRORS=$((ERRORS+1)); }
[ -d "services/systemd" ] || { echo "  ✗ Missing services/systemd"; ERRORS=$((ERRORS+1)); }
[ -f "services/systemd/pulse.service" ] || { echo "  ✗ Missing pulse.service"; ERRORS=$((ERRORS+1)); }

# Check bootstrap
echo "✓ Checking bootstrap structure..."
[ -d "bootstrap/wizard" ] || { echo "  ✗ Missing bootstrap/wizard"; ERRORS=$((ERRORS+1)); }
[ -f "bootstrap/wizard/server.py" ] || { echo "  ✗ Missing wizard server"; ERRORS=$((ERRORS+1)); }

# Check root files
echo "✓ Checking root files..."
[ -f "install.sh" ] || { echo "  ✗ Missing install.sh"; ERRORS=$((ERRORS+1)); }
[ -f "requirements.txt" ] || { echo "  ✗ Missing requirements.txt"; ERRORS=$((ERRORS+1)); }
[ -f "config.yaml" ] || { echo "  ✗ Missing config.yaml"; ERRORS=$((ERRORS+1)); }

# Check __init__.py files
echo "✓ Checking Python package structure..."
[ -f "services/__init__.py" ] || { echo "  ✗ Missing services/__init__.py"; ERRORS=$((ERRORS+1)); }
[ -f "services/hub/__init__.py" ] || { echo "  ✗ Missing services/hub/__init__.py"; ERRORS=$((ERRORS+1)); }
[ -f "services/sensors/__init__.py" ] || { echo "  ✗ Missing services/sensors/__init__.py"; ERRORS=$((ERRORS+1)); }
[ -f "services/integrations/__init__.py" ] || { echo "  ✗ Missing services/integrations/__init__.py"; ERRORS=$((ERRORS+1)); }

echo ""
if [ $ERRORS -eq 0 ]; then
    echo "=========================================="
    echo "✓ All checks passed!"
    echo "=========================================="
    echo ""
    echo "Structure is correct. You can now:"
    echo "1. Push changes to GitHub"
    echo "2. Run installation on Raspberry Pi:"
    echo "   curl -fsSL https://raw.githubusercontent.com/Opentab1/lordofthepowers/main/install.sh | sudo bash"
    exit 0
else
    echo "=========================================="
    echo "✗ Found $ERRORS errors"
    echo "=========================================="
    echo "Please review the structure before deploying."
    exit 1
fi
