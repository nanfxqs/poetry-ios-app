import importlib.util
import json
import pathlib
import tempfile
import unittest

MODULE = pathlib.Path(__file__).resolve().parents[1] / 'scripts/stitch-client.py'

class StitchClientTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('stitch_client', MODULE)
        cls.client = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.client)

    def test_progress_is_not_a_completed_response(self):
        parse = self.client.completed_response
        raw = b'data: {"jsonrpc":"2.0","method":"notifications/progress","params":{}}\n\n'
        self.assertIsNone(parse(raw, 'call-1'))
        raw += b'data: {"id":"other","result":{}}\n\n'
        self.assertIsNone(parse(raw, 'call-1'))
        raw += b'data: {"id":"call-1",\ndata: "result":{"content":[]}}\n\n'
        self.assertEqual(parse(raw, 'call-1')['id'], 'call-1')

    def test_disconnect_after_server_acceptance_blocks_resubmission(self):
        submitted = []
        def disconnect(*args, **kwargs):
            submitted.append(1)
            raise ConnectionError('remote closed before response headers')
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            for prompt in ['original', 'reworded attempt']:
                with self.assertRaises((ConnectionError, self.client.PendingOperation)):
                    self.client.execute('edit_screens', {'projectId':'p','prompt':prompt},
                        root/'out.json', root/'state', disconnect)
            self.assertEqual(len(submitted), 1, 'An uncertain mutation must not be submitted again')
            state = json.loads((root/'state/pending.json').read_text())
            self.assertEqual(state['status'], 'unknown')
            self.assertEqual(state['stage'], 'request')

    def test_successful_response_is_cached_without_resubmission(self):
        calls = []
        def success(method, args, request_id, trace):
            calls.append(1)
            return {'id':request_id,'result':{'content':[]}}
        with tempfile.TemporaryDirectory() as tmp:
            root=pathlib.Path(tmp)
            for _ in range(2):
                self.client.execute('edit_screens', {'projectId':'p'},root/'out.json',root/'state',success)
            self.assertEqual(len(calls), 1)

    def test_read_only_requests_remain_available_when_mutation_is_unknown(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=pathlib.Path(tmp)
            root.joinpath('state').mkdir()
            root.joinpath('state/pending.json').write_text('{"status":"unknown"}')
            self.client.execute('get_project', {'name':'projects/p'}, root/'out.json',root/'state',
                lambda method,args,request_id,trace: {'id':request_id,'result':{'content':[]}})
            self.assertTrue(root.joinpath('state/pending.json').exists())

if __name__ == '__main__':
    unittest.main()
