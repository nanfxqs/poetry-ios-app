"""Private poetry JSON API and local maintainer CLI; Python standard library only."""
import argparse
import collection_backup
from contextlib import contextmanager
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import sqlite3
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MAX_PACKAGE = 8_000_000


@contextmanager
def database(path):
    db = sqlite3.connect(path)
    db.execute('PRAGMA journal_mode=WAL')
    db.execute('CREATE TABLE IF NOT EXISTS content(version INTEGER PRIMARY KEY, package BLOB NOT NULL)')
    try:
        with db:
            yield db
    finally:
        db.close()


def validate(raw):
    if len(raw) > MAX_PACKAGE:
        raise ValueError('package too large')
    envelope = json.loads(raw)
    if envelope['schemaVersion'] != 1 or type(envelope['version']) is not int or envelope['version'] <= 0:
        raise ValueError('unsupported version')
    payload = envelope['payload'].encode('utf-8')
    if hashlib.sha256(payload).hexdigest() != envelope['sha256']:
        raise ValueError('checksum mismatch')
    content = json.loads(payload)
    if set(content) != {'poems', 'catalogs'} or set(content['catalogs']) != {'poets', 'places', 'placeAssociations', 'tags', 'lifeEvents', 'relationships'}:
        raise ValueError('unsupported catalogs')
    ids = set()
    if not content['poems']:
        raise ValueError('empty reading sequence')
    for poem in content['poems']:
        for key in ('id', 'poetID'):
            if not re.fullmatch(r'[a-z0-9][a-z0-9._-]{0,127}', poem[key]):
                raise ValueError('invalid stable ID')
        if poem['id'] in ids:
            raise ValueError('duplicate poem ID')
        ids.add(poem['id'])
        if not poem['title'] or not poem['poet'] or not poem['lines'] or not all(isinstance(x, str) and x for x in poem['lines']):
            raise ValueError('incomplete poem')
        if not poem['sources'] or not all(s['title'] and s['license'] and s['url'].startswith('https://') for s in poem['sources']):
            raise ValueError('missing source or license')
    catalogs = content['catalogs']
    def identity(rows):
        values = [r['id'] for r in rows]
        if len(values) != len(set(values)) or not all(re.fullmatch(r'[a-z0-9][a-z0-9._-]{0,127}', v) for v in values):
            raise ValueError('duplicate or invalid catalog ID')
        return set(values)
    def evidence(e):
        return isinstance(e['note'], str) and e['title'] and e['license'] and e['url'].startswith('https://')
    poets = identity(catalogs['poets'])
    places = identity(catalogs['places'])
    if not {p['poetID'] for p in content['poems']} <= poets:
        raise ValueError('missing author')
    for poet in catalogs['poets']:
        if poet.get('biography') is not None and not isinstance(poet['biography'], str):
            raise ValueError('invalid biography')
        if not poet['name'] or not isinstance(poet['dynasty'], str) or not poet['sources'] or not all(evidence(e) for e in poet['sources']):
            raise ValueError('invalid poet')
    for place in catalogs['places']:
        if not place['name'] or not isinstance(place['precision'], str) or not isinstance(place['caveat'], str) or not evidence(place['geography']):
            raise ValueError('invalid place')
        r = place.get('region')
        if r is not None and not (-90 <= r['south'] <= r['north'] <= 90 and -180 <= r['west'] <= r['east'] <= 180):
            raise ValueError('invalid region')
    edges = set()
    for edge in catalogs['placeAssociations']:
        key = (edge['placeID'], edge['poemID'], edge['kind'])
        if key in edges or key[0] not in places or key[1] not in ids or key[2] not in ('诗中之地', '写作地') or not evidence(edge['evidence']):
            raise ValueError('invalid place reference')
        edges.add(key)
    if not set(catalogs['tags']) <= ids:
        raise ValueError('invalid tag reference')
    for tags in catalogs['tags'].values():
        if set(tags) != {'imagery', 'topics', 'emotions'} or not all(isinstance(a, list) and all(isinstance(t, str) for t in a) for a in tags.values()):
            raise ValueError('invalid tags')
    identity(catalogs['lifeEvents'])
    for event in catalogs['lifeEvents']:
        if event.get('uncertainty') is not None and not isinstance(event['uncertainty'], str):
            raise ValueError('invalid uncertainty')
        if event['poetID'] not in poets or not event['title'] or not event['period'] or not event['sources'] or not all(evidence(e) for e in event['sources']):
            raise ValueError('invalid life event')
        if event.get('chronology') is not None and type(event['chronology']) is not int:
            raise ValueError('invalid chronology')
        for link in event['poemLinks']:
            if link['poemID'] not in ids or link['kind'] not in ('associated', 'contemporary') or not link['sources'] or not all(evidence(e) for e in link['sources']):
                raise ValueError('invalid life poem reference')
    identity(catalogs['relationships'])
    poem_authors = {p['id']: p['poetID'] for p in content['poems']}
    for relation in catalogs['relationships']:
        links = relation['evidencePoemIDs']
        if (relation['fromPoetID'] not in poets or relation['toPoetID'] not in poets
                or relation['fromPoetID'] == relation['toPoetID']
                or not isinstance(relation['kind'], str) or not relation['kind']
                or not isinstance(relation['summary'], str) or not relation['summary']
                or not isinstance(links, list) or not links or not all(isinstance(v, str) for v in links)
                or len(set(links)) != len(links)
                or not all(poem_authors.get(v) == relation['fromPoetID'] for v in links)
                or not isinstance(relation['sources'], list) or not relation['sources']
                or not all(evidence(e) for e in relation['sources'])):
            raise ValueError('invalid relationship evidence')
    return envelope


def publish(path, raw):
    package = validate(raw)
    with database(path) as db:
        db.execute('BEGIN IMMEDIATE')
        current = db.execute('SELECT COALESCE(MAX(version),0) FROM content').fetchone()[0]
        if package['version'] <= current:
            raise ValueError('version must increase')
        db.execute('INSERT INTO content VALUES (?,?)', (package['version'], raw))


def create_server(address, db_path, token):
    if len(token) < 32 or any(c.isspace() for c in token):
        raise ValueError('private token must contain at least 32 non-whitespace characters')
    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *_):
            pass  # URLs, credentials and payloads never enter access logs.

        def send_json(self, value):
            raw = json.dumps(value, allow_nan=False).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', str(len(raw)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(raw)

        def do_PUT(self):
            if not hmac.compare_digest(self.headers.get('Authorization', '').encode(), ('Bearer ' + token).encode()):
                self.send_error(401)
                return
            if self.path != '/v1/backup':
                self.send_error(404)
                return
            try:
                size = int(self.headers.get('Content-Length', '0'))
                if not 0 < size <= MAX_PACKAGE:
                    self.send_error(413)
                    return
                self.connection.settimeout(30)
                snapshot = json.loads(self.rfile.read(size))
                with database(db_path) as db:
                    receipt = collection_backup.save(db, snapshot)
            except (ValueError, KeyError, TypeError, AttributeError):
                self.send_error(409)
                return
            self.send_json(receipt)

        def do_GET(self):
            if not hmac.compare_digest(self.headers.get('Authorization', '').encode('utf-8'), ('Bearer ' + token).encode('utf-8')):
                self.send_error(401)
                return
            if self.path == '/v1/media/swale-v1.wav':
                try:
                    audio = (Path(__file__).resolve().parent / 'media/swale-v1.wav').read_bytes()
                except OSError:
                    self.send_error(503)
                    return
                if hashlib.sha256(audio).hexdigest() != '2f1f2c9472d68e2acd51809bfed4174f46aab419cbd36f85194237af40558766':
                    self.send_error(503)
                    return
                self.send_response(200)
                self.send_header('Content-Type', 'audio/wav')
                self.send_header('Content-Length', str(len(audio)))
                self.send_header('Cache-Control', 'private, no-store')
                self.end_headers()
                self.wfile.write(audio)
                return
            if self.path == '/v1/backup':
                with database(db_path) as db:
                    receipt = collection_backup.latest(db)
                if receipt is None:
                    self.send_error(404)
                else:
                    self.send_json(receipt)

                return
            if self.path != '/v1/content':
                self.send_error(404)
                return
            with database(db_path) as db:
                row = db.execute('SELECT package FROM content ORDER BY version DESC LIMIT 1').fetchone()
            if row is None:
                self.send_error(404)
                return
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.send_header('Content-Length', str(len(row[0])))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            self.wfile.write(row[0])
    return ThreadingHTTPServer(address, Handler)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--database', default='/data/poetry.sqlite')
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ('validate', 'publish'):
        sub.add_parser(name).add_argument('package')
    pack = sub.add_parser('pack')
    pack.add_argument('payload'); pack.add_argument('output'); pack.add_argument('--version', type=int, required=True)
    serve = sub.add_parser('serve')
    serve.add_argument('--host', default='0.0.0.0'); serve.add_argument('--port', type=int, default=8080)
    args = parser.parse_args()
    if args.command == 'pack':
        payload = Path(args.payload).read_text()
        raw = json.dumps(dict(schemaVersion=1, version=args.version, sha256=hashlib.sha256(payload.encode()).hexdigest(), payload=payload), ensure_ascii=False).encode()
        validate(raw)
        Path(args.output).write_bytes(raw)
    elif args.command in ('validate', 'publish'):
        raw = Path(args.package).read_bytes()
        validate(raw)
        if args.command == 'publish':
            publish(args.database, raw)
        print('Content package validated' if args.command == 'validate' else 'Content published')
    else:
        token = Path(os.environ['POETRY_TOKEN_FILE']).read_text().strip()
        create_server((args.host, args.port), args.database, token).serve_forever()


if __name__ == '__main__':
    main()
