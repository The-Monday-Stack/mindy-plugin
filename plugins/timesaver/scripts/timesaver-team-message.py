#!/usr/bin/env python3
"""Send from the cloud using a code read through the connected-folder tools."""
import datetime
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid

PROMPT = 'What would you like to send to Mike?'
SENT = 'Your message has been sent to Mike.'
DUPLICATE = 'Your message was already sent to Mike.'
UNREACHABLE = 'MINDY TimeSaver could not reach the server.'
ALLOW_DOMAIN = 'Allow gate.mindy.build under Settings > Capabilities > Additional allowed domains in the Claude app, then type /mindyteam again.'
NO_CODE = 'MINDY TimeSaver could not read your connected access code. Click the </> button, choose Local and type /install-mts with your access code there. Then return to this chat and type /mindyteam again.'


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def endpoint():
    url = os.environ.get('MTS_TEAM_MESSAGE_TEST_URL', 'https://gate.mindy.build/mts/team-messages')
    if 'MTS_TEAM_MESSAGE_TEST_URL' in os.environ:
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme != 'http' or parsed.hostname != '127.0.0.1' or not parsed.port or parsed.path != '/mts/team-messages' or parsed.username or parsed.password or parsed.query or parsed.fragment:
            raise ValueError('invalid test endpoint')
    return url


def failure(reason, message, code):
    def redact(text):
        return text.replace(code, '[access code]') if code else text
    reason = ' '.join(redact(reason).splitlines())
    print(reason + ' Your message: ' + json.dumps(redact(message), ensure_ascii=False) + '. Type /mindyteam again to try again.')
    return 1


def send(data):
    message = data.get('message', '')
    code = data.get('accessCode', '')
    if not isinstance(message, str) or not message.strip():
        print(PROMPT)
        return 1
    if not isinstance(code, str) or not 1 <= len(code) <= 4096 or any(ord(c) <= 32 or ord(c) >= 127 for c in code):
        return failure(NO_CODE, message, code if isinstance(code, str) else '')
    body = dict(report='mts-team-message/v1', messageId=str(uuid.uuid4()), app='Claude app',
                message=message.replace(code, '[access code]').strip()[:10000], sentAt=datetime.datetime.now(datetime.timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z'))
    try:
        request = urllib.request.Request(endpoint(), data=json.dumps(body, ensure_ascii=False).encode('utf-8'),
                                         headers={'Authorization': 'Bearer ' + code, 'Content-Type': 'application/json'}, method='POST')
        opener = urllib.request.build_opener(NoRedirect())
        try:
            response = opener.open(request, timeout=15)
        except urllib.error.HTTPError as error:
            response = error
        with response:
            status = response.code
            if status == 201:
                print(SENT)
                return 0
            try:
                answer = json.loads(response.read(65536))
            except (ValueError, UnicodeError):
                answer = None
            if status == 200 and isinstance(answer, dict) and answer.get('duplicate') is True:
                print(DUPLICATE)
                return 0
            if status in (403, 429) and isinstance(answer, dict) and isinstance(answer.get('error'), str) and answer['error'].strip():
                return failure(answer['error'].replace('Mindy TimeSaver', 'MINDY TimeSaver'), message, code)
        return failure(UNREACHABLE, message, code)
    except urllib.error.URLError as error:
        if not isinstance(error, urllib.error.HTTPError) and any(text in str(error.reason) for text in ('Tunnel connection failed', '407', '403', 'Forbidden')):
            return failure(ALLOW_DOMAIN, message, code)
        return failure(UNREACHABLE, message, code)
    except Exception:
        return failure(UNREACHABLE, message, code)


if __name__ == '__main__':
    try:
        sys.exit(send(json.load(sys.stdin)))
    except Exception:
        print(UNREACHABLE)
        sys.exit(1)
