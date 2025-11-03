#!/bin/bash
# Quick test script for health monitor functionality

echo "================================================"
echo "  Pulse Health Monitor - Test Script"
echo "================================================"
echo ""

# Change to installation directory
cd /opt/pulse 2>/dev/null || cd "$(dirname "$0")"

# Activate virtual environment if it exists
if [ -f "venv/bin/activate" ]; then
    source venv/bin/activate
fi

echo "Testing HealthMonitor imports..."
python3 -c "
from services.sensors.health_monitor import HealthMonitor, test_camera, test_microphone, test_bme280, test_pan_tilt, test_ai_hat, test_light_sensor
print('✓ All imports successful')
"

if [ $? -ne 0 ]; then
    echo "❌ Import test failed!"
    exit 1
fi

echo ""
echo "Running hardware detection tests..."
echo ""

python3 -m services.sensors.health_monitor

echo ""
echo "================================================"
echo "Test complete!"
echo ""
echo "Check results:"
echo "  cat config/hardware_status.json"
echo ""
echo "Service status:"
echo "  sudo systemctl status pulse-health"
echo "================================================"
