#!/usr/bin/env python3
"""
Pulse Health Monitor - Tests and monitors all hardware modules
"""
import asyncio
import json
import time
import subprocess
from pathlib import Path
from typing import Dict, Callable, Any
import logging

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

STATUS_FILE = Path(__file__).resolve().parents[2] / 'config' / 'hardware_status.json'


class HealthMonitor:
    """Monitor hardware health and run periodic tests"""
    
    def __init__(self):
        self.tests: Dict[str, Callable] = {}
        self.last_results: Dict[str, Dict[str, Any]] = {}
        
    def register_test(self, name: str, test_func: Callable):
        """Register a hardware test function"""
        self.tests[name] = test_func
        logger.info(f"Registered test: {name}")
        
    def run_test(self, name: str) -> Dict[str, Any]:
        """Run a single test"""
        if name not in self.tests:
            return {'present': False, 'error': 'Test not registered'}
        
        try:
            result = self.tests[name]()
            self.last_results[name] = result
            return result
        except Exception as e:
            logger.error(f"Test {name} failed: {e}")
            return {'present': False, 'error': str(e)}
    
    def test_all_modules(self) -> Dict[str, Any]:
        """Run all registered tests"""
        results = {}
        for name in self.tests:
            results[name] = self.run_test(name)
        return results
    
    def save_results(self):
        """Save test results to status file"""
        status = {
            'last_check': time.time(),
            'last_checked': time.strftime('%Y-%m-%d %H:%M:%S'),
            'modules': self.last_results
        }
        
        STATUS_FILE.parent.mkdir(parents=True, exist_ok=True)
        with open(STATUS_FILE, 'w') as f:
            json.dump(status, f, indent=2)
        logger.info(f"Saved results to {STATUS_FILE}")
    
    def run_continuous_monitoring(self, interval: int = 60):
        """Run continuous monitoring loop"""
        logger.info(f"Starting continuous monitoring (interval: {interval}s)")
        while True:
            try:
                self.test_all_modules()
                self.save_results()
                logger.info(f"Health check complete. Next check in {interval}s")
            except Exception as e:
                logger.error(f"Monitoring error: {e}")
            
            time.sleep(interval)


# Hardware test functions
def test_camera() -> Dict[str, Any]:
    """Test camera availability"""
    try:
        camera_exists = Path('/dev/video0').exists()
        if camera_exists:
            # Try to verify it's accessible
            try:
                result = subprocess.run(
                    ['v4l2-ctl', '--list-devices'],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    timeout=5,
                    text=True
                )
                devices = result.stdout
                return {
                    'present': True,
                    'status': 'OK',
                    'info': f"Camera device found: {devices.split()[0] if devices else '/dev/video0'}"
                }
            except:
                return {'present': True, 'status': 'OK', 'info': 'Camera device exists'}
        return {'present': False, 'status': 'Not Found'}
    except Exception as e:
        return {'present': False, 'error': str(e)}


def test_microphone() -> Dict[str, Any]:
    """Test microphone availability"""
    try:
        result = subprocess.run(
            ['arecord', '-l'],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=5,
            text=True
        )
        has_mic = 'card' in result.stdout.lower()
        if has_mic:
            # Extract card info
            lines = result.stdout.split('\n')
            card_info = lines[0] if lines else 'Unknown'
            return {
                'present': True,
                'status': 'OK',
                'info': card_info
            }
        return {'present': False, 'status': 'Not Found'}
    except Exception as e:
        return {'present': False, 'error': str(e)}


def test_bme280() -> Dict[str, Any]:
    """Test BME280 sensor on I2C"""
    try:
        for bus in ['0', '1']:
            result = subprocess.run(
                ['i2cdetect', '-y', bus],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=5,
                text=True
            )
            # BME280 typically at 0x76 or 0x77
            if '76' in result.stdout or '77' in result.stdout:
                addr = '0x76' if '76' in result.stdout else '0x77'
                return {
                    'present': True,
                    'status': 'OK',
                    'info': f'Found on I2C bus {bus} at {addr}'
                }
        return {'present': False, 'status': 'Not Found'}
    except Exception as e:
        return {'present': False, 'error': str(e)}


def test_pan_tilt() -> Dict[str, Any]:
    """Test pan/tilt servo availability"""
    try:
        # Check if GPIO is accessible
        gpio_base = Path('/sys/class/gpio')
        if gpio_base.exists():
            return {
                'present': True,
                'status': 'OK',
                'info': 'GPIO available for servo control'
            }
        return {'present': False, 'status': 'GPIO not available'}
    except Exception as e:
        return {'present': False, 'error': str(e)}


def test_ai_hat() -> Dict[str, Any]:
    """Test AI HAT availability"""
    try:
        # Check for device tree info
        dt_path = Path('/proc/device-tree/model')
        if dt_path.exists():
            model = dt_path.read_text(errors='ignore')
            if 'Raspberry Pi' in model:
                # Check for AI accelerator modules
                result = subprocess.run(
                    ['lsmod'],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    timeout=5,
                    text=True
                )
                mods = result.stdout.lower()
                if 'hailo' in mods:
                    return {
                        'present': True,
                        'status': 'OK',
                        'info': 'Hailo AI accelerator detected'
                    }
        return {'present': False, 'status': 'Not Found', 'info': 'Optional hardware'}
    except Exception as e:
        return {'present': False, 'error': str(e)}


def test_light_sensor() -> Dict[str, Any]:
    """Test light sensor availability"""
    try:
        # Check for light sensor on I2C (common addresses)
        for bus in ['0', '1']:
            result = subprocess.run(
                ['i2cdetect', '-y', bus],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=5,
                text=True
            )
            # Common light sensor addresses: 0x23 (BH1750), 0x29 (TSL2561), 0x39 (APDS-9960)
            for addr in ['23', '29', '39']:
                if addr in result.stdout:
                    return {
                        'present': True,
                        'status': 'OK',
                        'info': f'Found on I2C bus {bus} at 0x{addr}'
                    }
        return {'present': False, 'status': 'Not Found', 'info': 'Optional hardware'}
    except Exception as e:
        return {'present': False, 'error': str(e)}


async def read_status():
    """Read current hardware status from file"""
    if not STATUS_FILE.exists():
        return {"last_check": None, "modules": {}}
    try:
        data = json.loads(STATUS_FILE.read_text())
        if not isinstance(data, dict):
            return {"last_check": None, "modules": {}}
        if "modules" not in data or not isinstance(data.get("modules"), dict):
            return {
                "last_check": data.get("last_check") or data.get("last_checked"),
                "modules": {}
            }
        return data
    except Exception:
        return {"last_check": None, "modules": {}}


async def run_detection():
    """Run hardware detection asynchronously"""
    from . import hardware_detect
    try:
        hardware_detect.main()
    except Exception:
        pass


async def main_loop():
    """Main async monitoring loop"""
    retry_interval = 60
    while True:
        await run_detection()
        await asyncio.sleep(retry_interval)


if __name__ == '__main__':
    try:
        # If run directly, start continuous monitoring
        monitor = HealthMonitor()
        monitor.register_test('camera', test_camera)
        monitor.register_test('microphone', test_microphone)
        monitor.register_test('bme280', test_bme280)
        monitor.register_test('pan_tilt', test_pan_tilt)
        monitor.register_test('ai_hat', test_ai_hat)
        monitor.register_test('light_sensor', test_light_sensor)
        
        # Run once and print results
        results = monitor.test_all_modules()
        monitor.save_results()
        
        print(json.dumps({
            'last_check': time.time(),
            'modules': results
        }, indent=2))
        
    except KeyboardInterrupt:
        logger.info("Monitoring stopped by user")
