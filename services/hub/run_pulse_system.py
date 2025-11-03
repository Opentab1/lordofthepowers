#!/usr/bin/env python3
"""
Pulse System Runner
Runs the Pulse FastAPI Hub
"""

import logging
import sys
import os
from pathlib import Path

# Auto-detect Pulse installation directory
SCRIPT_DIR = Path(__file__).resolve().parent.parent.parent

# Try common locations
PULSE_DIRS = [
    SCRIPT_DIR,
    Path('/workspace'),
    Path('/opt/pulse'),
    Path.home() / 'pulse',
]

PULSE_ROOT = None
for pd in PULSE_DIRS:
    if (pd / 'services' / 'hub' / 'main.py').exists():
        PULSE_ROOT = pd
        break

if PULSE_ROOT is None:
    print("ERROR: Cannot find Pulse installation!")
    print(f"Searched: {[str(p) for p in PULSE_DIRS]}")
    sys.exit(1)

print(f"Found Pulse at: {PULSE_ROOT}")

# Add paths
sys.path.insert(0, str(PULSE_ROOT))
sys.path.insert(0, str(PULSE_ROOT / 'services'))
os.chdir(str(PULSE_ROOT))

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)

logger = logging.getLogger(__name__)

def main():
    """Main entry point"""
    logger.info("="*80)
    logger.info("PULSE HUB - Starting")
    logger.info("="*80)
    logger.info(f"Working directory: {PULSE_ROOT}")
    logger.info("Hub will be available at: http://localhost:7000")
    logger.info("="*80)
    
    # Create required directories
    os.makedirs("/var/log/pulse", exist_ok=True)
    os.makedirs(PULSE_ROOT / "data", exist_ok=True)
    os.makedirs(PULSE_ROOT / "config", exist_ok=True)
    
    try:
        # Import and run FastAPI app with uvicorn
        import uvicorn
        
        # Import the FastAPI app
        sys.path.insert(0, str(PULSE_ROOT / 'services' / 'hub'))
        from main import app
        
        # Run the server
        uvicorn.run(
            app,
            host="0.0.0.0",
            port=7000,
            log_level="info"
        )
        
    except KeyboardInterrupt:
        logger.info("="*80)
        logger.info("PULSE HUB - Shutting down")
        logger.info("="*80)
        sys.exit(0)
    except Exception as e:
        logger.error(f"Error starting Pulse Hub: {e}", exc_info=True)
        sys.exit(1)

if __name__ == "__main__":
    main()
