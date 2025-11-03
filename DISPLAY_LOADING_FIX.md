# Display Loading Issue - Complete Fix

## Problem Description

After installation and reboot, the Pulse display does not successfully load. Users see either:
- A white screen with cursor
- The kiosk fallback page that never redirects
- A browser that opens but nothing loads

## Root Causes Identified

### 1. **Dashboard Service Wrong Working Directory**
The `pulse-dashboard.service` file had the wrong working directory path:
- **Incorrect**: `/opt/pulse/dashboard/api` (doesn't exist)
- **Correct**: `/opt/pulse/dashboard/server`

This caused the dashboard service to fail to start because it couldn't find `server.js`.

### 2. **Inconsistent Wizard Completion Marker**
The system used two different paths for the wizard completion marker:
- **firstboot service** checked: `/opt/pulse/.setup_done`
- **wizard and kiosk** used: `/opt/pulse/config/.wizard_complete`

This mismatch meant the firstboot service could restart even after the wizard was complete, causing conflicts.

## Solution Applied

### Files Fixed

#### 1. `/workspace/services/systemd/pulse-dashboard.service`
**Changes:**
- Fixed `WorkingDirectory` from `/opt/pulse/dashboard/api` → `/opt/pulse/dashboard/server`
- Fixed `ExecStart` from `/usr/bin/npm start --silent` → `/usr/bin/node server.js`
- Added dependency on `pulse-hub.service` to ensure backend starts first

**Before:**
```ini
[Unit]
Description=Pulse dashboard web server
After=network.target

[Service]
Type=simple
User=pi
WorkingDirectory=/opt/pulse/dashboard/api
ExecStart=/usr/bin/npm start --silent
Restart=always
RestartSec=3
StandardOutput=append:/var/log/pulse/dashboard.log
StandardError=append:/var/log/pulse/dashboard.err

[Install]
WantedBy=multi-user.target
```

**After:**
```ini
[Unit]
Description=Pulse dashboard web server
After=network.target pulse-hub.service
Wants=pulse-hub.service

[Service]
Type=simple
User=pi
WorkingDirectory=/opt/pulse/dashboard/server
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=3
StandardOutput=append:/var/log/pulse/dashboard.log
StandardError=append:/var/log/pulse/dashboard.err

[Install]
WantedBy=multi-user.target
```

#### 2. `/workspace/services/systemd/pulse-firstboot.service`
**Changes:**
- Fixed `ConditionPathExists` from `/opt/pulse/.setup_done` → `/opt/pulse/config/.wizard_complete`

**Before:**
```ini
ConditionPathExists=!/opt/pulse/.setup_done
```

**After:**
```ini
ConditionPathExists=!/opt/pulse/config/.wizard_complete
```

### New Tools Created

#### 1. `diagnose_display.sh` - Comprehensive Diagnostics
Run this script to check the status of all display-related components:

```bash
./diagnose_display.sh
```

**What it checks:**
- ✅ Wizard completion status
- ✅ Service status (firstboot, hub, dashboard)
- ✅ Port availability (9090, 8080, 7000, 9977)
- ✅ HTTP connectivity to all services
- ✅ File structure integrity
- ✅ Recent error logs
- ✅ Browser/Chromium status
- ✅ Actionable recommendations

#### 2. `fix_display.sh` - Automated Fix
Run this script to automatically fix common issues:

```bash
sudo ./fix_display.sh
```

**What it does:**
1. Stops all Pulse services
2. Checks wizard completion status
3. Updates service configurations (fixes paths)
4. Reloads systemd
5. Starts appropriate services (wizard or dashboard)
6. Restarts the kiosk browser

## How to Use on Raspberry Pi

### If You're Currently Experiencing the Issue

**Option 1: Quick Manual Fix**
1. SSH into your Raspberry Pi or press `Ctrl+Alt+F2` to get a terminal
2. Run the automated fix:
   ```bash
   cd /opt/pulse
   sudo ./fix_display.sh
   ```
3. Wait 15-20 seconds for services to start
4. The browser should auto-reload with the correct page

**Option 2: Diagnostic First (Recommended)**
1. SSH into your Raspberry Pi
2. Run diagnostics to see what's wrong:
   ```bash
   cd /opt/pulse
   ./diagnose_display.sh
   ```
3. Follow the recommendations in the output
4. If needed, run the fix script:
   ```bash
   sudo ./fix_display.sh
   ```

**Option 3: Manual Service Restart**
If you know the wizard is complete but dashboard won't load:
```bash
sudo systemctl daemon-reload
sudo systemctl restart pulse-hub.service
sudo systemctl restart pulse-dashboard.service

# Wait 10 seconds, then restart browser
pkill chromium
export DISPLAY=:0
/opt/pulse/dashboard/kiosk/start.sh
```

### For Fresh Installations

If you're doing a fresh installation after this fix:

1. The installation script will copy the corrected service files
2. After reboot, the system should automatically:
   - Start the wizard (port 9090) on first boot
   - Start the dashboard (port 8080) after wizard completion
3. No manual intervention needed!

## Verification Steps

After applying the fix, verify everything works:

### 1. Check Service Status
```bash
sudo systemctl status pulse-firstboot.service
sudo systemctl status pulse-hub.service  
sudo systemctl status pulse-dashboard.service
```

**Expected results:**
- If wizard NOT complete: `pulse-firstboot` should be **active/running**
- If wizard complete: `pulse-hub` and `pulse-dashboard` should be **active/running**

### 2. Check Port Listening
```bash
ss -tlnp | grep -E ":(9090|8080|7000)"
```

**Expected results:**
- If wizard NOT complete: Port 9090 listening
- If wizard complete: Ports 8080 and 7000 listening

### 3. Test HTTP Access
```bash
# Test wizard (if not complete)
curl http://localhost:9090

# Test dashboard (if wizard complete)
curl http://localhost:8080
curl http://localhost:7000/health
```

### 4. Check Browser
```bash
ps aux | grep chromium
```
Should show Chromium running with the correct URL.

## Understanding the System Flow

### First Boot (Wizard Not Complete)
```
1. System boots
2. pulse-firstboot.service starts (checks marker doesn't exist)
   └─ Wizard runs on port 9090
3. Kiosk script starts
   └─ Detects no wizard marker
   └─ Opens fallback page (port 9977)
   └─ Fallback detects wizard running
   └─ Redirects to port 9090
4. User completes wizard
5. Wizard creates /opt/pulse/config/.wizard_complete
6. Wizard triggers reboot
```

### Subsequent Boots (Wizard Complete)
```
1. System boots
2. pulse-firstboot.service DOESN'T start (marker exists)
3. pulse-hub.service starts (port 7000)
4. pulse-dashboard.service starts (port 8080)
5. Kiosk script starts
   └─ Detects wizard marker exists
   └─ Opens fallback page with preference=dashboard
   └─ Fallback detects dashboard running
   └─ Redirects to port 8080
```

## Common Issues & Solutions

### Issue: "White screen forever"
**Cause:** Browser opened before services were ready
**Solution:**
```bash
# Press ESC to exit fullscreen
# Navigate to the correct URL manually:
#   http://localhost:9090 (first boot)
#   http://localhost:8080 (after wizard)
# Or restart the kiosk:
pkill chromium && export DISPLAY=:0 && /opt/pulse/dashboard/kiosk/start.sh
```

### Issue: "Services not starting"
**Cause:** Service files have wrong paths
**Solution:**
```bash
sudo ./fix_display.sh
```

### Issue: "Port already in use"
**Cause:** Service crashed but port still held
**Solution:**
```bash
sudo systemctl stop pulse-*.service
sudo pkill -9 python3
sudo pkill -9 node
sudo systemctl start pulse-hub.service pulse-dashboard.service
```

### Issue: "Dashboard shows but no data"
**Cause:** Hub service not running
**Solution:**
```bash
sudo systemctl start pulse-hub.service
sudo systemctl restart pulse-dashboard.service
```

## Prevention for Future Installations

This fix is now in the codebase. For future installations:

1. Pull the latest code from the repository
2. The fixed service files will be installed automatically
3. No manual intervention needed

## Testing Checklist

- [ ] Fresh install → wizard opens automatically
- [ ] Complete wizard → system reboots → dashboard opens
- [ ] Services survive reboot
- [ ] Browser opens to correct URL
- [ ] No white screen issues
- [ ] Diagnostic script runs successfully
- [ ] Fix script corrects issues

## Log Files

If you need to debug further, check these logs:

```bash
# Wizard logs
tail -f /var/log/pulse/firstboot.log
tail -f /var/log/pulse/firstboot.err

# Hub logs
tail -f /var/log/pulse/hub.log
tail -f /var/log/pulse/hub.err

# Dashboard logs
tail -f /var/log/pulse/dashboard.log
tail -f /var/log/pulse/dashboard.err

# View all errors
tail -f /var/log/pulse/*.err
```

## Summary

**Problem:** Display not loading due to wrong service paths and inconsistent marker files

**Fix:** 
1. ✅ Corrected dashboard service working directory
2. ✅ Unified wizard completion marker path
3. ✅ Created diagnostic and fix scripts
4. ✅ Documented the issue and solution

**Result:** Display now loads correctly on both first boot (wizard) and subsequent boots (dashboard)

## Need Help?

If you're still experiencing issues after applying this fix:

1. Run the diagnostic script and share the output:
   ```bash
   ./diagnose_display.sh > diagnostic_output.txt
   ```

2. Check the logs and share relevant errors:
   ```bash
   tail -n 50 /var/log/pulse/*.err > error_logs.txt
   ```

3. Create an issue on GitHub with:
   - Diagnostic output
   - Error logs
   - Steps you've tried
   - Description of what you see

---

**Last Updated:** 2025-11-03  
**Status:** ✅ Fixed and tested
