"""Consistent SQLite backups. Restore always creates a new, isolated database."""
import argparse
from contextlib import closing
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import tempfile
import time
import uuid


def readonly(path):
    return sqlite3.connect(Path(path).resolve().as_uri() + '?mode=ro', uri=True)


def validate(path):
    with closing(readonly(path)) as db:
        if db.execute('PRAGMA integrity_check').fetchall() != [('ok',)]:
            raise ValueError('SQLite integrity check failed')
        # Refuse unrelated databases; an empty collection is permitted.
        db.execute('SELECT version, package FROM content LIMIT 1')


def digest(path):
    with open(path, 'rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def copy_database(source, destination):
    """Publish only a complete, validated backup; never overwrite a destination."""
    destination = Path(destination)
    destination.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.snapshot-', dir=destination.parent)
    os.close(fd)
    try:
        with closing(readonly(source)) as src, closing(sqlite3.connect(temporary)) as dst:
            src.backup(dst)
            dst.execute('PRAGMA journal_mode=DELETE')
        validate(temporary)
        with open(temporary, 'rb') as stream:
            os.fsync(stream.fileno())
        os.link(temporary, destination)  # atomic no-clobber publication
        directory = os.open(destination.parent, os.O_RDONLY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
        return destination
    finally:
        Path(temporary).unlink(missing_ok=True)


def snapshot(database, directory):
    directory = Path(directory)
    name = datetime.now(timezone.utc).strftime('poetry-%Y%m%dT%H%M%S.%fZ-') + uuid.uuid4().hex + '.sqlite'
    result = copy_database(database, directory / name)
    # Rotation follows successful publication, never a failed backup.
    for old in sorted(directory.glob('poetry-*.sqlite'), reverse=True)[7:]:
        old.unlink()
    return result


def export(source, destination, expected_sha256=None):
    if expected_sha256 is not None and digest(source) != expected_sha256:
        raise ValueError('source SHA-256 mismatch')
    result = copy_database(source, destination)
    record = dict(file=result.name, sha256=digest(result), sourceSHA256=digest(source),
                  exportedAt=datetime.now(timezone.utc).isoformat())
    receipt = result.with_suffix(result.suffix + '.json')
    with receipt.open('x') as stream:
        json.dump(record, stream, indent=2)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='command', required=True)
    for name in ('snapshot', 'daily', 'restore', 'export'):
        command = sub.add_parser(name)
        command.add_argument('source'); command.add_argument('destination')
        if name in ('restore', 'export'):
            command.add_argument('--sha256')
    check = sub.add_parser('verify'); check.add_argument('source')
    args = parser.parse_args()
    if args.command == 'verify':
        validate(args.source)
        print(json.dumps(dict(sha256=digest(args.source))))
    elif args.command == 'daily':
        # Persisted snapshot age prevents restart loops from consuming daily retention.
        while True:
            try:
                copies = list(Path(args.destination).glob('poetry-*.sqlite'))
                newest = max((p.stat().st_mtime for p in copies), default=0)
                remaining = 86400 - (time.time() - newest)
                if remaining > 0:
                    time.sleep(min(remaining, 60))
                    continue
                print(snapshot(args.source, args.destination), flush=True)
            except (OSError, sqlite3.Error, ValueError) as error:
                print('Snapshot failed: ' + type(error).__name__, flush=True)
                time.sleep(300)
    elif args.command == 'snapshot':
        print(snapshot(args.source, args.destination))
    else:
        print(json.dumps(export(args.source, args.destination, args.sha256)))


if __name__ == '__main__':
    main()
