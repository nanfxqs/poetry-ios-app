#!/usr/bin/env python3
"""Stitch fallback client: one submission, durable receipt, read-only recovery.

Credentials are read from Codex config and passed to curl on stdin, never argv.
Unknown mutations block all further mutations on this project until reconciled.
"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
import tomllib
import uuid

READ_ONLY = {'get_project', 'list_projects', 'get_screen', 'list_screens', 'list_design_systems'}

class PendingOperation(RuntimeError):
    pass

def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    temp = path.with_suffix(path.suffix + '.tmp')
    with temp.open('w', encoding='utf-8') as f:
        os.chmod(temp, 0o600)
        json.dump(value, f, ensure_ascii=False, indent=2)
        f.write('\n')
        f.flush()
        os.fsync(f.fileno())
    temp.replace(path)

def completed_response(raw, request_id):
    text = raw.decode('utf-8', errors='replace')
    candidates = [text]
    for event in text.replace('\r\n', '\n').split('\n\n')[:-1]:
        lines = [line[5:].lstrip(' ') for line in event.splitlines() if line.startswith('data:')]
        if lines:
            candidates.append('\n'.join(lines))
    for candidate in candidates:
        try:
            value = json.loads(candidate)
        except json.JSONDecodeError:
            continue
        if isinstance(value, dict) and value.get('id') == request_id and ('result' in value or 'error' in value):
            return value
    return None

def transport(method, args, request_id, trace):
    config = Path(os.environ.get('CODEX_HOME', str(Path.home()/'.codex')))/'config.toml'
    cfg = tomllib.loads(config.read_text())['mcp_servers']['stitch']
    endpoint = cfg['url']
    if endpoint != 'https://stitch.googleapis.com/mcp':
        raise ValueError('Unexpected Stitch endpoint; inspect configuration before sending credentials')
    payload = {'jsonrpc':'2.0','id':request_id,'method':'tools/call',
               'params':{'name':method,'arguments':args,'_meta':{'progressToken':request_id}}}
    headers = dict(cfg.get('http_headers', {}))
    for name, env in cfg.get('env_http_headers', {}).items():
        headers[name] = os.environ[env]
    headers.update({'Content-Type':'application/json','Accept':'application/json, text/event-stream',
                    'MCP-Protocol-Version':'2025-03-26'})
    # curl configuration quoting, not shell interpolation.
    def quote(value):
        return '"'+value.replace('\\','\\\\').replace('"','\\"').replace('\r','\\r').replace('\n','\\n')+'"'
    curl_config = '\n'.join('header = '+quote(k+': '+v) for k,v in headers.items())+'\n'
    timeout = max(1, float(cfg.get('tool_timeout_sec', 600)))
    started = time.monotonic()
    with tempfile.TemporaryDirectory(prefix='stitch-http-') as directory:
        tmp = Path(directory)
        body = tmp/'request.json'
        save(body, payload)
        head = tmp/'response.headers'
        with (tmp/'stderr').open('wb') as errors:
            process = subprocess.Popen(['curl','--config','-','--http2','--silent','--show-error',
                '--no-buffer','--connect-timeout','15','--max-time',str(timeout),
                '--keepalive-time','30','--keepalive-cnt','3','--dump-header',str(head),
                '--data-binary','@'+str(body),endpoint],
                stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=errors)
            raw = bytearray()
            try:
                process.stdin.write(curl_config.encode())
                process.stdin.close()
                while True:
                    chunk = process.stdout.read1(65536)
                    if not chunk:
                        break
                    if not raw:
                        trace['first_byte_seconds'] = round(time.monotonic()-started, 3)
                    raw.extend(chunk)
                    response = completed_response(raw, request_id)
                    if response is not None:
                        trace['complete_response_received'] = True
                        return response
                process.wait()
                raise ConnectionError('No complete matching MCP response; remote outcome is unknown')
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                        process.wait()
                process.stdout.close()
                trace['elapsed_seconds'] = round(time.monotonic()-started, 3)
                trace['curl_exit_code'] = process.returncode
                trace['received_bytes'] = len(raw)
                statuses = [line for line in head.read_text().splitlines() if line.startswith('HTTP/')] if head.exists() else []
                trace['http_status_lines'] = statuses
                trace['stage'] = 'body' if raw else ('response_headers' if statuses else 'request')

def execute(method, args, output, state, sender=transport):
    state.mkdir(parents=True, exist_ok=True)
    mutating = method not in READ_ONLY
    fingerprint = hashlib.sha256(json.dumps([method,args],sort_keys=True,ensure_ascii=False).encode()).hexdigest()
    cached = state/(fingerprint+'.response.json')
    pending = state/'pending.json'
    # Nonblocking lock: don't hide concurrent mutation behind a long wait.
    with (state/'mutation.lock').open('a') as lock:
        if mutating:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX|fcntl.LOCK_NB)
            except BlockingIOError as e:
                raise PendingOperation('Another Stitch mutation is active for this project') from e
            if pending.exists():
                raise PendingOperation('Previous mutation is unresolved: inspect pending.json and query get_project/get_screen; do not resubmit')
            if cached.exists():
                response=json.loads(cached.read_text())
                save(output,response)
                return response
        receipt = {'request_id':str(uuid.uuid4()),'tool':method,'fingerprint':fingerprint,
                   'started_at':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),
                   'status':'submitted','stage':'request','output':str(output.resolve())}
        if mutating:
            save(pending,receipt)
        try:
            response=sender(method,args,receipt['request_id'],receipt)
            save(output,response)
            if 'error' in response or response.get('result',{}).get('isError'):
                receipt['status']='needs_review'
                if mutating:
                    save(pending,receipt)
                raise PendingOperation('MCP returned an error; review before any further mutation')
            if mutating:
                save(cached,response)
                pending.unlink()
            receipt['status']='response_received'
            return response
        except BaseException as error:
            if receipt['status']=='submitted':
                receipt.update(status='unknown',error_type=type(error).__name__)
                if mutating:
                    save(pending,receipt)
            raise
        finally:
            save(output.with_suffix(output.suffix+'.receipt.json'),receipt)

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('tool')
    parser.add_argument('arguments',type=Path)
    parser.add_argument('output',type=Path)
    opts=parser.parse_args()
    args=json.loads(opts.arguments.read_text())
    project=args.get('projectId') or args.get('name','global')
    if project.startswith('projects/'):
        project=project.split('/')[1]
    state_base=Path(os.environ.get('XDG_STATE_HOME',str(Path.home()/'.local/state')))/'poetry-stitch'
    state=state_base/hashlib.sha256(project.encode()).hexdigest()[:20]
    try:
        response=execute(opts.tool,args,opts.output,state)
    except (Exception,KeyboardInterrupt) as error:
        print(f'{type(error).__name__}: request did not complete safely. Receipt: {opts.output}.receipt.json; state: {state}')
        return 2
    print('MCP response saved:',opts.output)
    print('Result is a response, not proof of canvas persistence; verify screen IDs with read-only calls.')
    return 0

if __name__=='__main__':
    raise SystemExit(main())
