"""Single authorized device, immutable full collection revisions in the shared SQLite DB."""
import json
import math
import time
import uuid


def prepare(db):
    db.execute('CREATE TABLE IF NOT EXISTS collection_snapshots (revision INTEGER PRIMARY KEY, device_id TEXT NOT NULL, snapshot TEXT NOT NULL, received_at REAL NOT NULL)')


def validate(snapshot):
    if set(snapshot) != {'deviceID', 'revision', 'favorites'}:
        raise ValueError('invalid snapshot')
    if str(uuid.UUID(snapshot['deviceID'])) != snapshot['deviceID'] or type(snapshot['revision']) is not int or not 0 < snapshot['revision'] < 2**63-1:
        raise ValueError('invalid identity or revision')
    if not isinstance(snapshot['favorites'], list):
        raise ValueError('invalid favorites')
    ids = set()
    for item in snapshot['favorites']:
        poem = item['poem']
        if set(item) != {'poem', 'savedAt'} or type(item['savedAt']) not in (int, float) or not math.isfinite(item['savedAt']):
            raise ValueError('invalid saved time')
        if not all(isinstance(poem[k], str) and poem[k] for k in ('id', 'title', 'poetID', 'poet', 'dynasty')) or poem['id'] in ids:
            raise ValueError('invalid poem')
        if not isinstance(poem['lines'], list) or not poem['lines'] or not all(isinstance(s, str) and s for s in poem['lines']):
            raise ValueError('invalid poem lines')
        if not isinstance(poem['sources'], list) or not all(all(isinstance(s[k], str) for k in ('title', 'url', 'license', 'note')) for s in poem['sources']):
            raise ValueError('invalid sources')
        if poem.get('background') is not None and not isinstance(poem['background'], str):
            raise ValueError('invalid background')
        ids.add(poem['id'])


def latest(db):
    prepare(db)
    row = db.execute('SELECT snapshot, received_at FROM collection_snapshots ORDER BY revision DESC LIMIT 1').fetchone()
    return None if row is None else dict(snapshot=json.loads(row[0]), receivedAt=row[1])


def save(db, snapshot):
    validate(snapshot)
    prepare(db)
    db.execute('BEGIN IMMEDIATE')
    current = latest(db)
    if current:
        previous = current['snapshot']
        if previous == snapshot:
            return current
        if previous['deviceID'] != snapshot['deviceID'] or snapshot['revision'] <= previous['revision']:
            raise ValueError('device or revision conflict')
    receipt = dict(snapshot=snapshot, receivedAt=time.time())
    db.execute('INSERT INTO collection_snapshots VALUES (?,?,?,?)', (snapshot['revision'], snapshot['deviceID'], json.dumps(snapshot, allow_nan=False), receipt['receivedAt']))
    return receipt
