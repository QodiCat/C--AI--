import contextlib
import importlib.util
import io
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import urllib.error

spec = importlib.util.spec_from_file_location('check_amap', Path(__file__).resolve().parents[1] / 'check_amap.py')
amap = importlib.util.module_from_spec(spec)
spec.loader.exec_module(amap)


class DiagnosticTests(unittest.TestCase):
    def test_environment_wins_and_quotes(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / '.env'
            path.write_text('export AMAP_API_KEY="file-key"\n', encoding='utf-8')
            with patch.dict(os.environ, {}, clear=True):
                self.assertEqual(amap.load_config(path)['AMAP_API_KEY'], 'file-key')
            with patch.dict(os.environ, {'AMAP_API_KEY': ''}, clear=True):
                self.assertEqual(amap.load_config(path)['AMAP_API_KEY'], '')

    def test_safe_errors(self):
        from unittest.mock import MagicMock
        for code in ['10001', '10002', '10003', '10005', '10009', 'secret-key']:
            opener = MagicMock()
            opener.open.return_value.__enter__.return_value.read.return_value = (
                '{"status":"0","infocode":"%s","info":"secret-key"}' % code).encode()
            data, message = amap.request(opener, 'https://restapi.amap.com', 'secret-key', '/test', {})
            self.assertIsNone(data)
            self.assertNotIn('secret-key', message)
        opener.open.side_effect = urllib.error.URLError('https://host/?key=secret-key')
        self.assertNotIn('secret-key', amap.request(opener, '', '', '', {})[1])

    def test_weather_runs_after_coordinate_failure(self):
        answers = [(None, 'infocode=10002'), ({'lives': [{}]}, 'OK'), ({'forecasts': [{}]}, 'OK')]
        with patch.object(amap, 'load_config', return_value={
                'AMAP_API_KEY': 'secret-key', 'AMAP_BASE_URL': 'https://restapi.amap.com'}), \
                patch.object(amap, 'request', side_effect=answers) as request, \
                contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(amap.main([]), 1)
            self.assertEqual(request.call_count, 3)
            self.assertNotIn('secret-key', output.getvalue())

    def test_success(self):
        answers = [({'locations': '116.4,39.9'}, 'OK'),
                   ({'regeocode': {'addressComponent': {'adcode': '110101'}}}, 'OK'),
                   ({'lives': [{}]}, 'OK'), ({'forecasts': [{}]}, 'OK')]
        with patch.object(amap, 'load_config', return_value={
                'AMAP_API_KEY': 'secret-key', 'AMAP_BASE_URL': 'https://restapi.amap.com'}), \
                patch.object(amap, 'request', side_effect=answers), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(amap.main([]), 0)

    def test_redirect_blocked(self):
        self.assertIsNone(amap.NoRedirect().redirect_request(None, None, 302, '', {}, 'https://other/'))
