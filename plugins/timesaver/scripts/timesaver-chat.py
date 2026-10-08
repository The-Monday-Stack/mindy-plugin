#!/usr/bin/env python3
"""Prepare the Mac writer's JSONL records. File transfers use connected-folder tools."""
import datetime
import hashlib
import json
import re
import sys
from zoneinfo import ZoneInfo


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'))


def digest(value):
    return hashlib.sha256(('mts-canonical-json-v1\n' + canonical(value)).encode()).hexdigest()


def prepare(data):
    marker = data['marker']
    if marker.get('format') != 'mts.connected-folder.v1' or marker.get('product') != 'mts':
        raise ValueError('Click + beside the message box, choose Add folder, and pick the folder called timesaver in your home folder. Then type /mindyend again.')
    privacy = data['privacy']
    if not isinstance(privacy, dict) or type(privacy.get('off')) is not bool:
        raise ValueError('MINDY TimeSaver could not read your saving setting. Saving has stopped.')
    if privacy['off']:
        raise ValueError("I can't save this session because MINDY TimeSaver is switched off. Type /timesaver-on to switch it on, then type /mindyend to save this session.")
    session = data['sessionId']
    slug = data['slug']
    if not isinstance(session, str) or not session.strip() or len(session) > 1024:
        raise ValueError('MINDY TimeSaver could not identify this running session. Saving has stopped.')
    if not re.fullmatch('[a-z0-9]+(?:-[a-z0-9]+)*', slug):
        raise ValueError('MINDY TimeSaver could not name this session. Saving has stopped.')
    entries = data['entries']
    if not entries or sum(e.get('type') == 'summary' for e in entries) != 1:
        raise ValueError('MINDY TimeSaver needs one summary of the whole session.')
    for entry in entries:
        if entry.get('type') not in ['summary', 'observation', 'request', 'decision', 'commitment', 'action'] or not isinstance(entry.get('content'), str) or not entry['content'].strip():
            raise ValueError('MINDY TimeSaver could not prepare this session. Saving has stopped.')
    entries = [dict(type=e['type'], content=e['content'].strip()) for e in entries]
    stamp = data['timestamp']
    date = datetime.datetime.fromisoformat(stamp.replace('Z', '+00:00')).astimezone(ZoneInfo(marker['timezone'])).date().isoformat()
    metadata = dict(sessionId=session, slug=slug)
    artifact = f'sessions/{date[:4]}/session-{date}-{slug}.jsonl'
    capture = 'mts-manual-capture:' + digest(dict(version='mts-manual-capture-v4', sessionId=session, routeDate=date, metadata=metadata, entries=entries))
    rows = []
    for index, entry in enumerate(entries):
        provenance = dict(version='mts-capture-provenance-v1', capture_id=capture, session_id=session, artifact_relative_path=artifact,
                          transcript_identity=None, transcript_sha256=None, source_range_sha256=None, start_source_line=None,
                          end_source_line=None, prompt_version=None, model=None, intelligence_level=None, code_version=None, completeness='unknown')
        row = dict(timestamp=stamp, type=entry['type'], content=entry['content'], metadata=metadata, entry_id=f'mts-entry:{capture}:{index+1:04d}', provenance=provenance)
        semantic = dict(row, provenance={k:v for k,v in provenance.items() if k != 'artifact_relative_path'})
        entry_hash = digest(dict(version='mts-raw-entry-hash-v1', entry=semantic))
        row['entry_hash'] = entry_hash
        participation = hashlib.sha256(f"mts-participation-v1\n{row['entry_id']}\ncreation\n{entry_hash}".encode()).hexdigest()
        row['events_participation_key'] = 'mts-participation-v1:' + participation
        rows.append(row)
    return dict(path='MY-MIND/MY-PERCEPTION/TIMESAVER/' + artifact, content=''.join(json.dumps(row, ensure_ascii=False, separators=(',', ':')) + '\n' for row in rows), count=len(rows), summary=next(e['content'] for e in entries if e['type'] == 'summary'))


if __name__ == '__main__':
    try:
        print(json.dumps(prepare(json.load(sys.stdin)), ensure_ascii=False))
    except (KeyError, ValueError, TypeError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
