# Installation Fix - HealthMonitor Error

## Problem
The installation script was failing at step [11/11] with the error:
```
NameError: name 'HealthMonitor' is not defined
```

## Root Cause
The `pulse-health.service` systemd service file was referencing a `HealthMonitor` class that didn't exist in the `services/sensors/health_monitor.py` file. 

The service file expected:
- `HealthMonitor` class with `register_test()` and `run_continuous_monitoring()` methods
- Test functions: `test_camera`, `test_microphone`, `test_bme280`, `test_pan_tilt`, `test_ai_hat`, `test_light_sensor`

But the `health_monitor.py` file only contained basic async functions without the class structure.

## Solution Applied

### 1. Created Complete HealthMonitor Class
**File: `services/sensors/health_monitor.py`**

Added:
- `HealthMonitor` class with test registration and monitoring capabilities
- All required test functions:
  - `test_camera()` - Checks `/dev/video0` and verifies with `v4l2-ctl`
  - `test_microphone()` - Uses `arecord -l` to detect audio input
  - `test_bme280()` - Scans I2C buses for sensor at 0x76/0x77
  - `test_pan_tilt()` - Verifies GPIO availability for servo control
  - `test_ai_hat()` - Detects Hailo AI accelerator via `lsmod`
  - `test_light_sensor()` - Scans I2C for light sensors (BH1750, TSL2561, APDS-9960)

Features:
- Automatic test result saving to `config/hardware_status.json`
- Continuous monitoring mode with configurable intervals
- Proper logging and error handling
- JSON output format for easy parsing

### 2. Improved Installation Script Error Handling
**File: `install.sh`**

Enhanced the hardware detection phase (step 11/11) to:
- Better exception handling in the Python parsing script
- Display raw output if JSON parsing fails
- Always save detection results even on errors
- Clearer error messages

## Testing the Fix

After pulling these changes, the installation should complete successfully:

```bash
curl -fsSL https://raw.githubusercontent.com/Opentab1/lordofthepowers/main/install.sh | sudo bash
```

You can also test the health monitor directly:

```bash
cd /opt/pulse
source venv/bin/activate
python3 -m services.sensors.health_monitor
```

Expected output:
```json
{
  "last_check": 1699999999.999,
  "modules": {
    "camera": {"present": true, "status": "OK", "info": "..."},
    "microphone": {"present": true, "status": "OK", "info": "..."},
    "bme280": {"present": false, "status": "Not Found"},
    ...
  }
}
```

## Service Status

The `pulse-health.service` should now start correctly:

```bash
sudo systemctl status pulse-health
```

## Files Changed
1. `services/sensors/health_monitor.py` - Complete rewrite with HealthMonitor class
2. `install.sh` - Improved error handling in hardware detection phase

## Next Steps
After this fix is deployed, the installation will:
1. ✅ Complete all 11 installation steps without errors
2. ✅ Enable and start the health monitoring service
3. ✅ Generate a proper hardware report at `/var/log/pulse/hardware_report.json`
4. ✅ Reboot and launch the setup wizard successfully
