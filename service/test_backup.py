import http.client
import json
from pathlib import Path
import tempfile
import threading
import unittest
from poetry_service import create_server


class BackupHTTPTests(unittest.TestCase):
    def test_auth_revision_cancel_restart_and_restore(self):
        with tempfile.TemporaryDirectory() as directory:
            db = str(Path(directory) / 'poetry.sqlite')
            poem = json.loads((Path(__file__).resolve().parents[1] / 'Sources/PoetryCore/Resources/seed.json').read_text())[0]
            snapshot = dict(deviceID='11111111-1111-1111-1111-111111111111', revision=1, favorites=[dict(poem=poem, savedAt=1234)])
            def request(method, payload=None, authorized=True):
                client = http.client.HTTPConnection(*server.server_address)
                client.request(method, '/v1/backup', body=json.dumps(payload) if payload is not None else None,
                               headers={'Authorization': 'Bearer ' + 't' * 32} if authorized else {})
                response = client.getresponse()
                body = response.read()
                client.close()
                return response.status, json.loads(body) if response.status == 200 else None
            for restart in range(2):
                server = create_server(('127.0.0.1', 0), db, 't' * 32)
                worker = threading.Thread(target=server.serve_forever); worker.start()
                try:
                    self.assertEqual(request('GET', authorized=False)[0], 401)
                    self.assertEqual(request('PUT', snapshot, False)[0], 401)
                    if restart == 0:
                        self.assertEqual(request('GET')[0], 404)
                        code, receipt = request('PUT', snapshot)
                        self.assertEqual(code, 200)
                        self.assertEqual(receipt['snapshot'], snapshot)
                        self.assertEqual(request('PUT', snapshot), (200, receipt))
                        self.assertEqual(request('PUT', dict(snapshot, favorites=[]))[0], 409)
                        self.assertEqual(request('PUT', dict(snapshot, deviceID='22222222-2222-2222-2222-222222222222', revision=2))[0], 409)
                        self.assertEqual(request('PUT', dict(snapshot, revision=2, favorites=[]))[0], 200)
                        self.assertEqual(request('PUT', snapshot)[0], 409)
                    code, restored = request('GET')
                    self.assertEqual(code, 200)
                    self.assertEqual(restored['snapshot'], dict(snapshot, revision=2, favorites=[]))
                finally:
                    server.shutdown(); server.server_close(); worker.join()
