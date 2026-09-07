import hashlib
import http.client
import json
from pathlib import Path
import tempfile
import threading
import unittest
from poetry_service import create_server, publish, validate


def package(version=1, change=None):
    root = Path(__file__).resolve().parents[1]
    poems = json.loads((root / 'Sources/PoetryCore/Resources/seed.json').read_text())
    poets = [dict(id=p, name=p, dynasty='唐', sources=poems[0]['sources']) for p in sorted({p['poetID'] for p in poems})]
    payload = dict(poems=poems, catalogs=dict(poets=poets, places=[], placeAssociations=[], tags={}, lifeEvents=[]))
    if change:
        change(payload)
    text = json.dumps(payload, ensure_ascii=False)
    return json.dumps(dict(schemaVersion=1, version=version, sha256=hashlib.sha256(text.encode()).hexdigest(), payload=text)).encode()


class ServiceTests(unittest.TestCase):
    def test_actual_http_auth_restart_and_failed_publication(self):
        with tempfile.TemporaryDirectory() as directory:
            path = str(Path(directory) / 'poetry.sqlite')
            good = package()
            publish(path, good)
            with self.assertRaises(ValueError):
                publish(path, package(2, lambda c: c['poems'].append(c['poems'][0])))
            with self.assertRaises(ValueError):
                publish(path, package())
            for _ in range(2):
                server = create_server(('127.0.0.1', 0), path, 't' * 32)
                worker = threading.Thread(target=server.serve_forever)
                worker.start()
                try:
                    for endpoint, auth, expected in [('/v1/content', '', 401), ('/poetry.sqlite', 'Bearer ' + 't' * 32, 404), ('/v1/content', 'Bearer ' + 't' * 32, 200)]:
                        client = http.client.HTTPConnection(*server.server_address)
                        client.request('GET', endpoint, headers={'Authorization': auth})
                        response = client.getresponse()
                        self.assertEqual(response.status, expected)
                        body = response.read()
                        if expected == 200:
                            self.assertEqual(body, good)
                        client.close()
                finally:
                    server.shutdown(); server.server_close(); worker.join()

    def test_corrupt_incomplete_unknown_and_dangling_catalogs_rejected(self):
        for raw in [package()[:-20], package().replace(b'"sha256": "', b'"sha256": "bad'),
                    package(change=lambda c: c['catalogs']['poets'].clear()),
                    package(change=lambda c: c['catalogs'].update(unsupported=[])),
                    package(change=lambda c: c['catalogs']['tags'].update(missing=dict(imagery=[], topics=[], emotions=[])))]:
            with self.assertRaises((ValueError, KeyError)):
                validate(raw)


if __name__ == '__main__':
    unittest.main()
