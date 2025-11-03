# Installation Fix Summary

## Problem

When running the installation script, it failed at step [6/10] with the error:
```
bash: line 151: cd: /opt/pulse/dashboard/ui: No such file or directory
```

The install.sh script expected a specific directory structure that didn't match the actual repository layout.

## Root Cause

The repository had a **flat structure** with all files at the root level, but the install.sh script expected a **modular structure** with organized subdirectories:

**Expected by install.sh:**
```
/opt/pulse/
├── dashboard/
│   ├── ui/           # Frontend React app
│   └── kiosk/        # Kiosk startup script
└── services/
    ├── systemd/      # Systemd service files
    ├── sensors/      # Sensor modules
    └── hub/          # Backend hub
```

**What actually existed:**
```
/opt/pulse/
├── package.json      # All frontend files at root
├── App.tsx
├── main.tsx
├── server.py         # All Python files at root
├── bme280_reader.py
├── pulse.service     # All service files at root
└── ...
```

## Solution

Reorganized the repository to match the expected structure:

### 1. Dashboard Organization

**Frontend UI** (`dashboard/ui/`)
- Moved all React/Vite files: `package.json`, `vite.config.ts`, `tsconfig.json`, etc.
- Created `src/` directory structure:
  - `src/App.tsx` and `src/main.tsx` - Main app files
  - `src/components/` - All React components (LiveOverview, Analytics, Controls, etc.)
- Kept build configuration files at `dashboard/ui/` level

**Kiosk Mode** (`dashboard/kiosk/`)
- Created startup script: `dashboard/kiosk/start.sh`
- Created fallback HTML page: `dashboard/kiosk/index.html`
- Fallback page intelligently detects and redirects to wizard (port 9090) or dashboard (port 8080)

**Dashboard Server** (`dashboard/server/`)
- Moved Node.js Express proxy server: `server.js`

### 2. Services Organization

**Hub Services** (`services/hub/`)
- `main.py` - FastAPI hub server (main backend)
- `run_pulse_system.py` - System startup script (updated to work with new structure)
- `db.py` - Database module
- `hardware_detect.py` - Hardware detection
- `static_server.py` - Alternative static file server

**Sensor Services** (`services/sensors/`)
- All sensor modules: `bme280_reader.py`, `camera_people.py`, `person_detector.py`, etc.
- Health monitoring: `health_monitor.py`, `diagnose_sensors.py`
- Model management: `download_models.sh`
- Audio detection: `mic_song_detect.py`, `song_detector.py`
- Person tracking: `person_tracker.py`, `party_person_detector.py`

**Integration Services** (`services/integrations/`)
- HVAC: `hvac_nest.py`
- Lighting: `lighting_hue.py`
- Music: `music_local.py`, `music_spotify.py`
- TV Control: `tv_cec.py`, `tv_ip.py`

**Systemd Services** (`services/systemd/`)
- All systemd service files moved here
- Main service: `pulse.service` (updated to use new paths)
- Health monitoring: `pulse-health.service`
- First boot wizard: `pulse-firstboot.service`
- Individual sensor services: `pulse-bme280.service`, `pulse-camera.service`, etc.

### 3. Bootstrap Wizard

**First Boot Setup** (`bootstrap/wizard/`)
- `server.py` - Flask-based setup wizard (runs on port 9090)
- Guides user through initial configuration
- Creates `.wizard_complete` marker when done

### 4. Updated Files

**install.sh**
- Updated line 184-185: Changed paths for run_pulse_system.py and diagnose_sensors.py

**services/systemd/pulse.service**
- Updated line 12: Changed ExecStart path from `/opt/pulse/run_pulse_system.py` to `/opt/pulse/services/hub/run_pulse_system.py`

**services/hub/run_pulse_system.py**
- Completely rewritten to be simpler
- Now runs the FastAPI app from `services/hub/main.py` using uvicorn
- Removed complex threading and dashboard API logic
- Auto-detects Pulse installation directory
- Creates required directories automatically

**dashboard/kiosk/start.sh**
- Serves fallback HTML from kiosk directory
- HTML page intelligently tries wizard first (if not completed), then dashboard
- Provides helpful error messages if services aren't running

**dashboard/kiosk/index.html** (new)
- Loading page that checks for running services
- Automatically redirects to wizard (9090) or dashboard (8080)
- Shows connection status and helpful error messages

## Final Directory Structure

```
/opt/pulse/
├── bootstrap/
│   └── wizard/
│       └── server.py              # Setup wizard (Flask, port 9090)
├── dashboard/
│   ├── kiosk/
│   │   ├── start.sh               # Chromium kiosk launcher
│   │   └── index.html             # Fallback/loading page
│   ├── server/
│   │   └── server.js              # Express proxy server
│   └── ui/
│       ├── src/
│       │   ├── components/        # React components
│       │   ├── App.tsx
│       │   └── main.tsx
│       ├── index.html
│       ├── package.json
│       ├── vite.config.ts
│       └── ...
├── services/
│   ├── hub/
│   │   ├── main.py                # FastAPI hub server (port 7000)
│   │   ├── run_pulse_system.py   # Startup script
│   │   ├── db.py
│   │   ├── hardware_detect.py
│   │   └── static_server.py
│   ├── integrations/
│   │   ├── hvac_nest.py
│   │   ├── lighting_hue.py
│   │   ├── music_local.py
│   │   ├── music_spotify.py
│   │   ├── tv_cec.py
│   │   └── tv_ip.py
│   ├── sensors/
│   │   ├── bme280_reader.py       # Temperature/humidity/pressure
│   │   ├── camera_people.py       # Person detection
│   │   ├── light_level.py         # Light sensor
│   │   ├── mic_song_detect.py     # Song detection
│   │   ├── pan_tilt.py            # Camera control
│   │   ├── health_monitor.py      # Sensor health checks
│   │   ├── diagnose_sensors.py    # Diagnostics
│   │   └── download_models.sh     # AI model downloader
│   └── systemd/
│       ├── pulse.service          # Main unified service
│       ├── pulse-health.service   # Health monitoring
│       ├── pulse-firstboot.service # Setup wizard
│       └── ...
├── config/                        # Configuration files
├── data/                          # Database and data files
├── models/                        # AI models
├── music/                         # Local music files
├── venv/                          # Python virtual environment
├── install.sh                     # Updated installation script
├── requirements.txt               # Python dependencies
├── config.yaml                    # Main configuration
└── ...
```

## System Architecture

### Service Flow

1. **First Boot:**
   - `pulse-firstboot.service` starts wizard at http://localhost:9090
   - Kiosk browser opens fallback page, detects wizard, redirects
   - User completes setup wizard
   - Wizard creates `.wizard_complete` marker
   - System ready for normal operation

2. **Normal Operation:**
   - `pulse.service` runs `services/hub/run_pulse_system.py`
   - Starts FastAPI hub at http://localhost:7000
   - Frontend built files served (dashboard at port 8080)
   - Kiosk browser opens, detects dashboard, redirects

3. **Health Monitoring:**
   - `pulse-health.service` continuously monitors sensors
   - Uses `services/sensors/health_monitor.py`
   - Logs to `/var/log/pulse/health.log`

## Ports Used

- **7000** - FastAPI Hub (backend API)
- **8080** - Dashboard UI (frontend)
- **9090** - Setup Wizard (first boot only)
- **9977** - Kiosk fallback page (local HTTP server)

## Installation Command

The fixed installation now works correctly:

```bash
curl -fsSL https://raw.githubusercontent.com/Opentab1/lordofthepowers/main/install.sh | sudo bash
```

## Verification

After installation, verify the structure:
```bash
ls -la /opt/pulse/dashboard/ui/
ls -la /opt/pulse/services/hub/
ls -la /opt/pulse/services/sensors/
ls -la /opt/pulse/services/systemd/
```

Check that services can start:
```bash
sudo systemctl status pulse
sudo systemctl status pulse-health
```

## Next Steps

The installation should now complete successfully. After the system reboots:

1. Kiosk will automatically open to setup wizard
2. Complete the wizard configuration
3. Dashboard will launch automatically
4. All sensors will be available and monitored

## Files Modified

- `/workspace/install.sh` - Updated paths
- `/workspace/services/systemd/pulse.service` - Updated ExecStart path
- `/workspace/services/hub/run_pulse_system.py` - Complete rewrite
- Created: `/workspace/dashboard/kiosk/index.html` - New fallback page

## Files Moved

All files reorganized from flat root structure into modular directory structure as detailed above.
