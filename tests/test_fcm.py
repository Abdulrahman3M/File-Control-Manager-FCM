import importlib.util
from pathlib import Path
import tempfile
import unittest
import os
import subprocess
import sys
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('fcm',root/'fcm.py')
fcm=importlib.util.module_from_spec(spec)
spec.loader.exec_module(fcm)
class Tests(unittest.TestCase):
    def test_version(self):
        self.assertEqual(fcm.VERSION,'2.1.1')
    def test_numbered_menu_choices(self):
        self.assertEqual(fcm.normalize_menu_choice('01'), '1')
        self.assertEqual(fcm.normalize_menu_choice('1'), '1')
        self.assertEqual(fcm.normalize_menu_choice('11'), '11')
        self.assertEqual(fcm.normalize_menu_choice('x'), 'x')

    @unittest.skipUnless(os.name == 'nt', 'Windows-only TUI engine')
    def test_noninteractive_dashboard_smoke(self):
        process = subprocess.run([sys.executable, str(root / 'fcm.py'), '--smoke-test'],
                                 capture_output=True, text=True, encoding='utf-8')
        self.assertEqual(process.returncode, 0, process.stderr)
        self.assertIn('FILE CONTROL MANAGER', process.stdout)

    def test_validate(self):
        with tempfile.TemporaryDirectory() as root:
            p=Path(root)/'sample.txt'
            p.write_text('ok')
            self.assertEqual(fcm.safe_path(str(p)),p)
            with self.assertRaises(FileNotFoundError):fcm.safe_path(str(p)+'missing')
if __name__=='__main__':unittest.main()
