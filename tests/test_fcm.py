import importlib.util
from pathlib import Path
import tempfile
import unittest
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('fcm',root/'fcm.py')
fcm=importlib.util.module_from_spec(spec)
spec.loader.exec_module(fcm)
class Tests(unittest.TestCase):
    def test_version(self):
        self.assertEqual(fcm.VERSION,'2.1.0')
    def test_validate(self):
        with tempfile.TemporaryDirectory() as root:
            p=Path(root)/'sample.txt'
            p.write_text('ok')
            self.assertEqual(fcm.safe_path(str(p)),p)
            with self.assertRaises(FileNotFoundError):fcm.safe_path(str(p)+'missing')
if __name__=='__main__':unittest.main()
