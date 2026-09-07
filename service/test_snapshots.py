import http.client
import json
from pathlib import Path
import sqlite3
import tempfile
import threading
import unittest
from unittest.mock import patch
import collection_backup
from poetry_service import create_server, database, publish
from snapshots import snapshot, export, digest, validate
from test_service import package


class SnapshotTests(unittest.TestCase):
    def test_rotation_and_failure_preserve_all_previous_copies(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); db = root/'live.sqlite'; copies = root/'copies'
            publish(db, package())
            for _ in range(9):
                snapshot(db, copies)
            before = {p.name: digest(p) for p in copies.iterdir()}
            self.assertEqual(len(before), 7)
            with patch('snapshots.copy_database', side_effect=OSError('disk full')):
                with self.assertRaises(OSError):
                    snapshot(db, copies)
            with self.assertRaises(sqlite3.Error):
                snapshot(root/'missing.sqlite', copies)
            self.assertEqual(before, {p.name: digest(p) for p in copies.iterdir()})
            for p in copies.iterdir():
                validate(p)

    def test_export_restore_restart_and_explicit_client_recovery(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); live = root/'live.sqlite'
            good = package(); publish(live, good)
            poem = json.loads(json.loads(good)['payload'])['poems'][0]
            favorites = dict(deviceID='aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', revision=1,
                             favorites=[dict(poem=poem, savedAt=123.0)])
            with database(live) as db:
                collection_backup.save(db, favorites)
            # WAL connection remains open while the online backup runs.
            writer = sqlite3.connect(live)
            writer.execute('PRAGMA journal_mode=WAL')
            writer.execute('BEGIN IMMEDIATE')
            writer.execute('INSERT INTO content VALUES (?,?)', (2, package(2)))
            copy = snapshot(live, root/'copies')
            writer.rollback(); writer.close()
            exported = root/'linux'/'export.sqlite'
            receipt = export(copy, exported, digest(copy))
            self.assertEqual(receipt['sha256'], digest(exported))
            with self.assertRaises(ValueError):
                export(copy, root/'bad.sqlite', '0'*64)
            self.assertFalse((root/'bad.sqlite').exists())
            restored = root/'isolated'/'poetry.sqlite'
            export(exported, restored, receipt['sha256'])
            before = digest(live)
            with self.assertRaises(FileExistsError):
                export(exported, live)
            self.assertEqual(digest(live), before)
            # An empty client changes only after the explicit backup GET and restore.
            local_collection = []
            for _ in range(2):
                server = create_server(('127.0.0.1', 0), restored, 't'*32)
                thread = threading.Thread(target=server.serve_forever); thread.start()
                try:
                    client = http.client.HTTPConnection(*server.server_address)
                    client.request('GET', '/v1/content', headers={'Authorization': 'Bearer '+'t'*32})
                    response = client.getresponse()
                    self.assertEqual(response.status, 200); self.assertEqual(response.read(), good)
                    self.assertEqual(local_collection, [])
                    client.request('GET', '/v1/backup', headers={'Authorization': 'Bearer '+'t'*32})
                    response = client.getresponse(); self.assertEqual(response.status, 200)
                    recovered = json.loads(response.read())['snapshot']
                    self.assertEqual(recovered, favorites)
                    local_collection = recovered['favorites']
                    self.assertEqual(local_collection[0]['poem']['title'], poem['title'])
                    local_collection = []; client.close()
                finally:
                    server.shutdown(); server.server_close(); thread.join()

    def test_invalid_database_never_replaces_usable_export(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder); invalid = root/'corrupt.sqlite'
            invalid.write_bytes(b'broken')
            with self.assertRaises(sqlite3.DatabaseError):
                export(invalid, root/'restored.sqlite')
            self.assertFalse((root/'restored.sqlite').exists())
