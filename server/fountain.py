#!/usr/bin/env python3
"""From a Fountain — now spinning + letter book service.

Standard library only. Run it on the machine next to Icecast:

    DISCOGS_TOKEN=... AUDD_TOKEN=... DOCENT_PIN=... python3 server/fountain.py

Pages:   /          letter book (mobile)
         /docent    set the record by hand, approve letters
API:     GET  /api/now                    what's spinning
         GET  /api/letters?artist=&album=&song=
         POST /api/letters                leave a memory
         GET  /api/search?q=              search the crate
         POST /api/now      (docent)      set record by hand / back to auto
         GET  /api/pending  (docent)
         POST /api/letters/<id>/approve|reject  (docent)

DEMO=1 runs with a small sample crate and no outside services.
"""
import hmac, json, os, re, sqlite3, threading, time, unicodedata, uuid
import urllib.error, urllib.parse, urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
ENV = os.environ.get
PORT = int(ENV('FOUNTAIN_PORT', '8787'))
DATA = Path(ENV('FOUNTAIN_DATA', HERE / 'data'))
DISCOGS_USER = ENV('DISCOGS_USER', 'andrewcrena')
DISCOGS_TOKEN = ENV('DISCOGS_TOKEN', '')
AUDD_TOKEN = ENV('AUDD_TOKEN', '')
ICECAST_URL = ENV('ICECAST_URL', 'http://localhost:8000').rstrip('/')
STREAM_URL = ENV('STREAM_URL', ICECAST_URL + '/stream.mp3')
# Icecast paths passed through, so one tunnel (ngrok -> this service) serves the stream and the letter book
ICECAST_PATHS = re.compile(r'/(stream\.(mp3|ogg)|status-json\.xsl)')
RECOGNIZE_EVERY = int(ENV('RECOGNIZE_EVERY', '60'))
SAMPLE_BYTES = int(ENV('SAMPLE_BYTES', '400000'))  # ~10 s of 320 kbps MP3
DOCENT_PIN = ENV('DOCENT_PIN', '')
REQUIRE_APPROVAL = ENV('REQUIRE_APPROVAL', '1') != '0'
DEMO = ENV('DEMO', '0') == '1'
PAUSE = 1.1 if DISCOGS_TOKEN else 2.5  # Discogs allows 60 req/min with a token, 25 without
UA = 'FromAFountain/1.0 +https://github.com/andrew-crena/from-a-fountain'

DATA.mkdir(parents=True, exist_ok=True)
(DATA / 'releases').mkdir(exist_ok=True)
lock = threading.Lock()


def log(*a):
    print(time.strftime('%H:%M:%S'), *a, flush=True)


# ---------- text matching ----------
def norm(s):
    s = unicodedata.normalize('NFKD', s or '').encode('ascii', 'ignore').decode().lower()
    s = re.sub(r'\s*\(\d+\)$', '', s)            # Discogs "Name (2)"
    s = re.sub(r'\(.*?\)|\[.*?\]', ' ', s)        # (Remastered), [Live]
    s = re.sub(r'\b(remaster(ed)?|mono|stereo|version|edit)\b.*', ' ', s)
    s = re.sub(r'^the\s+|&|\band\b', ' ', s)
    return re.sub(r'[^a-z0-9]+', '', s)


def clean_name(s):
    s = (s or '').split(' = ')[0]                 # "Tatsuro Yamashita = 山下達郎"
    return re.sub(r'\s*\(\d+\)', '', s).strip()   # "Jungle (12)", "John Williams (4), ..."


# ---------- storage ----------
def db():
    c = sqlite3.connect(DATA / 'fountain.db')
    c.row_factory = sqlite3.Row
    return c


with db() as c:
    c.execute('''create table if not exists letters(
        id text primary key, created real, kind text, artist text, album text, song text,
        body text, name text, status text)''')
    c.execute('create table if not exists kv(k text primary key, v text)')


def kv_get(k, default=None):
    with db() as c:
        r = c.execute('select v from kv where k=?', (k,)).fetchone()
    return json.loads(r['v']) if r else default


def kv_set(k, v):
    with db() as c:
        c.execute('insert or replace into kv values(?,?)', (k, json.dumps(v)))


# ---------- Discogs ----------
def discogs(path):
    req = urllib.request.Request('https://api.discogs.com' + path, headers={'User-Agent': UA})
    if DISCOGS_TOKEN:
        req.add_header('Authorization', 'Discogs token=' + DISCOGS_TOKEN)
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)


def collection():
    p = DATA / 'collection.json'
    return json.loads(p.read_text()) if p.exists() else []


def cached_release(rid):
    p = DATA / 'releases' / f'{rid}.json'
    return json.loads(p.read_text()) if p.exists() else None


def basic_release(rid):
    """What the collection list alone knows, for records whose details aren't cached yet."""
    it = next((i for i in collection() if i['id'] == rid), None)
    if not it:
        return None
    return {'id': rid, 'title': it['title'], 'year': it.get('year'), 'artists': [{'name': it['artist']}],
            'labels': [{'name': it['label']}] if it.get('label') else [], 'tracklist': [], 'basic': True}


def release(rid):
    """Full release details (tracklist, credits, companies, images), cached on disk.
    Falls back to the collection's basic info when Discogs can't be reached."""
    d = cached_release(rid)
    if d or DEMO:
        return d or basic_release(rid)
    try:
        d = discogs(f'/releases/{rid}')
    except Exception as e:
        log('discogs release', rid, 'failed:', e)
        return basic_release(rid)
    # Reissues often lack the original session's credits and studio, so also keep the
    # original release's recording details (via its Discogs master).
    try:
        if d.get('master_id'):
            time.sleep(PAUSE)
            m = discogs(f"/masters/{d['master_id']}")
            d['_original_year'] = m.get('year') or None
            mr = m.get('main_release')
            if mr and mr != rid:
                time.sleep(PAUSE)
                o = discogs(f'/releases/{mr}')
                d['_original'] = {k: o.get(k) for k in ('id', 'extraartists', 'companies', 'notes', 'tracklist', 'released')}
    except Exception as e:
        log('discogs original for', rid, 'failed:', e)
    (DATA / 'releases' / f'{rid}.json').write_text(json.dumps(d))
    return d


def import_csv(path):
    """Load a Discogs collection export (Collection → Export) as the crate."""
    import csv
    items, seen = [], set()
    with open(path, newline='', encoding='utf-8-sig') as fh:
        for r in csv.DictReader(fh):
            rid = int(r['release_id'])
            if rid in seen:
                continue
            seen.add(rid)
            year = int(r['Released']) if (r.get('Released') or '0').isdigit() and int(r['Released']) else None
            items.append({'id': rid, 'title': r['Title'].strip(), 'year': year, 'artist': clean_name(r['Artist']),
                          'label': clean_name(r['Label'].split(',')[0]), 'format': r.get('Format'),
                          'folder': r.get('CollectionFolder'), 'thumb': None})
    (DATA / 'collection.json').write_text(json.dumps(items))
    return items


def sync_collection():
    """Pull the whole collection, then cache each release's details (rate-limit friendly)."""
    if DEMO:
        return
    try:
        items, page = [], 1
        while True:
            d = discogs(f'/users/{urllib.parse.quote(DISCOGS_USER)}/collection/folders/0/releases?per_page=100&page={page}')
            for it in d.get('releases', []):
                b = it['basic_information']
                items.append({'id': b['id'], 'title': b['title'], 'year': b.get('year'),
                              'artist': clean_name(b['artists'][0]['name']) if b.get('artists') else '',
                              'thumb': b.get('cover_image') or b.get('thumb')})
            if page >= d['pagination']['pages']:
                break
            page += 1
            time.sleep(PAUSE * 3)
        (DATA / 'collection.json').write_text(json.dumps(items))
        log(f'collection: {len(items)} records')
        for it in items:
            if not (DATA / 'releases' / f"{it['id']}.json").exists():
                release(it['id'])
                time.sleep(PAUSE * 3)
        log('collection details cached')
    except Exception as e:
        log('collection sync failed:', e)


def tracks_of(rel):
    return [t for t in rel.get('tracklist', []) if t.get('type_', 'track') == 'track']


# Packaging and pressing jobs, not people you hear on the record
SKIP_ROLES = re.compile(r'lacquer|master|design|photo|artwork|art direction|layout|liner notes|^notes|cover|'
                        r'pressed|reissue|coordinat|management|legal|sleeve|typograph|illustrat|a&r|executive|'
                        r'product manager|transfer|lettering|compiled|supervis|copyright|label|other', re.I)


def credits_for(rel, track_title):
    t = next((t for t in tracks_of(rel) if norm(t['title']) == norm(track_title)), None)
    out, seen = [], set()
    for ea in (t or {}).get('extraartists', []) + (rel.get('extraartists') or []):
        on, pos = ea.get('tracks', ''), (t or {}).get('position')
        # Skip credits marked for other tracks only ("A1, B2"); keep ranges ("A1 to B3") to be safe
        if on and pos and ' to ' not in on and pos not in [x.strip() for x in on.split(',')]:
            continue
        role = re.sub(r'\s*\[.*?\]', '', ea.get('role', '')).strip()
        if not role or SKIP_ROLES.search(role):
            continue
        key = (clean_name(ea['name']), role)
        if key not in seen:
            seen.add(key)
            out.append({'name': key[0], 'role': role})
    return out


def recorded_where(rel):
    places = [c['name'] for c in rel.get('companies') or [] if c.get('entity_type_name') == 'Recorded At']
    if not places:  # often only written in the notes: "Recorded at Columbia 30th Street Studio, NYC, ..."
        m = re.search(r'(recorded (?:live )?(?:at|in|on)\b[^\n]{3,160}?)(?:\.\s|\n|$)', rel.get('notes') or '', re.I)
        if m:
            places = [m.group(1).strip()]
    return places


MONTHS = 'Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec'.split()


def pretty_date(d):
    """Discogs '1959-08-17' / '1958-01-00' / '1971' -> 'Aug 17, 1959' / 'Jan 1958' / '1971'."""
    m = re.fullmatch(r'(\d{4})(?:-(\d\d))?(?:-(\d\d))?', d or '')
    if not m:
        return d or None
    y, mo, day = m.groups()
    if not mo or mo == '00':
        return y
    return f'{MONTHS[int(mo) - 1]} {int(day)}, {y}' if day and day != '00' else f'{MONTHS[int(mo) - 1]} {y}'


def card(rel, track_title, source):
    """Now-playing card built from a Discogs release (your pressing) plus its original's session details."""
    t = next((t for t in tracks_of(rel) if norm(t['title']) == norm(track_title)), None)
    orig = rel.get('_original') or {}
    credits = credits_for(orig, track_title) if orig else []
    if len(credits) < 2:
        credits = credits_for(rel, track_title) or credits
    imgs = rel.get('images') or []
    cover = next((i['uri'] for i in imgs if i.get('type') == 'primary'), imgs[0]['uri'] if imgs else None)
    year = rel.get('_original_year') or rel.get('year') or None
    return {
        'source': source, 'in_collection': True, 'release_id': rel['id'],
        'song': t['title'] if t else track_title, 'position': (t or {}).get('position'),
        'artist': ', '.join(clean_name(a['name']) for a in rel.get('artists', [])),
        'album': rel.get('title'), 'year': year,
        'released': pretty_date(orig.get('released') if rel.get('_original_year') else rel.get('released')),
        'pressing_year': rel.get('year') if rel.get('year') and rel.get('year') != year else None,
        'label': ', '.join(dict.fromkeys(l['name'] for l in rel.get('labels', []))) or None,
        'catno': next((l['catno'] for l in rel.get('labels', []) if l.get('catno') and l['catno'].lower() != 'none'), None),
        'side': (re.match(r'[A-Za-z]+', (t or {}).get('position') or '') or [None])[0],
        'recorded_at': recorded_where(orig) or recorded_where(rel),
        'credits': credits[:24], 'cover': cover, 'updated': time.time(),
    }


def find_in_crate(artist, title, album=None):
    a = norm(artist)
    best = by_album = None
    for it in collection():
        if norm(it['artist']) != a and a not in norm(it['artist']):
            continue
        rel = release(it['id'])
        if not rel:
            continue
        same_album = album and norm(rel.get('title')) == norm(album)
        if not any(norm(t['title']) == norm(title) for t in tracks_of(rel)):
            # No tracklist yet (Discogs unreachable): still match on the album title
            if same_album and rel.get('basic'):
                by_album = by_album or rel
            continue
        if same_album:
            return rel
        best = best or rel
    return best or by_album


# ---------- now playing ----------
def now():
    return kv_get('now', {'source': 'none'})


def set_now(n):
    kv_set('now', n)
    log('now spinning:', n.get('artist'), '-', n.get('song'), f"({n.get('source')})")


def audd_recognize(sample):
    boundary = uuid.uuid4().hex
    parts = []
    for k, v in (('api_token', AUDD_TOKEN), ('return', 'apple_music')):
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode())
    parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="s.mp3"\r\n'
                 f'Content-Type: audio/mpeg\r\n\r\n'.encode() + sample + b'\r\n')
    parts.append(f'--{boundary}--\r\n'.encode())
    req = urllib.request.Request('https://api.audd.io/', data=b''.join(parts), headers={
        'Content-Type': 'multipart/form-data; boundary=' + boundary, 'User-Agent': UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        d = json.load(r)
    if d.get('status') != 'success':
        raise RuntimeError(d.get('error'))
    return d.get('result')


def grab_sample():
    req = urllib.request.Request(STREAM_URL, headers={'User-Agent': UA, 'ngrok-skip-browser-warning': '1'})
    with urllib.request.urlopen(req, timeout=20) as r:
        buf = b''
        while len(buf) < SAMPLE_BYTES:
            chunk = r.read(SAMPLE_BYTES - len(buf))
            if not chunk:
                break
            buf += chunk
    return buf


def recognizer():
    if DEMO or not AUDD_TOKEN:
        log('recognition off (no AUDD_TOKEN)' if not DEMO else 'recognition off (demo)')
        return
    while True:
        try:
            if now().get('source') != 'manual':
                res = audd_recognize(grab_sample())
                cur = now()
                if res and (norm(res.get('title')) != norm(cur.get('song')) or norm(res.get('artist')) != norm(cur.get('artist'))):
                    rel = find_in_crate(res.get('artist'), res.get('title'), res.get('album'))
                    if rel:
                        set_now(card(rel, res['title'], 'auto'))
                    else:
                        art = ((res.get('apple_music') or {}).get('artwork') or {}).get('url', '')
                        set_now({'source': 'auto', 'in_collection': False, 'song': res.get('title'),
                                 'artist': res.get('artist'), 'album': res.get('album'),
                                 'year': (res.get('release_date') or '')[:4] or None, 'label': res.get('label'),
                                 'recorded_at': [], 'credits': [],
                                 'cover': art.replace('{w}', '600').replace('{h}', '600') or None,
                                 'updated': time.time()})
        except Exception as e:
            log('recognition:', e)
        time.sleep(RECOGNIZE_EVERY)


# ---------- letters ----------
def letter_out(r):
    return {k: r[k] for k in ('id', 'created', 'kind', 'artist', 'album', 'song', 'body', 'name')}


def letters_for(artist, album, song, limit=300):
    a, al, s = norm(artist), norm(album), norm(song)
    if not a:
        return []
    with db() as c:
        rows = c.execute("select * from letters where status='ok' order by created desc limit 2000").fetchall()
    out = []
    for r in rows:
        if norm(r['artist']) != a:
            continue
        score = 3 if s and norm(r['song']) == s else 2 if al and norm(r['album']) == al else 1
        out.append((score, letter_out(r) | {'match': {3: 'song', 2: 'album', 1: 'artist'}[score]}))
    out.sort(key=lambda x: -x[0])
    return [l for _, l in out[:limit]]


recent_posts = {}


def add_letter(d, ip):
    body = (d.get('body') or '').strip()
    artist = (d.get('artist') or '').strip()
    if not body or not artist:
        return 400, {'error': 'Write something, and say which artist it is about.'}
    if len(body) > 2000:
        return 400, {'error': 'Keep it under 2000 characters.'}
    with lock:
        ts = [t for t in recent_posts.get(ip, []) if time.time() - t < 600]
        if len(ts) >= 5:
            return 429, {'error': 'That is a lot of letters at once. Try again in a few minutes.'}
        recent_posts[ip] = ts + [time.time()]
    kind = d.get('kind') if d.get('kind') in ('song', 'album', 'artist') else 'artist'
    row = (uuid.uuid4().hex[:12], time.time(), kind, artist[:200],
           (d.get('album') or '').strip()[:200] if kind != 'artist' else '',
           (d.get('song') or '').strip()[:200] if kind == 'song' else '',
           body, (d.get('name') or '').strip()[:60], 'pending' if REQUIRE_APPROVAL else 'ok')
    with db() as c:
        c.execute('insert into letters values(?,?,?,?,?,?,?,?,?)', row)
    return 200, {'ok': True, 'pending': REQUIRE_APPROVAL}


def search(q):
    q = norm(q)
    if len(q) < 2:
        return []
    out = []
    for it in collection():
        rel = cached_release(it['id']) or {}  # never wait on Discogs while someone types
        if q in norm(it['artist']) or q in norm(it['title']):
            out.append({'release_id': it['id'], 'artist': it['artist'], 'album': it['title'], 'year': it['year'],
                        'thumb': it.get('thumb'), 'tracks': [t['title'] for t in tracks_of(rel)]})
        else:
            hits = [t['title'] for t in tracks_of(rel) if q in norm(t['title'])]
            if hits:
                out.append({'release_id': it['id'], 'artist': it['artist'], 'album': it['title'], 'year': it['year'],
                            'thumb': it.get('thumb'), 'tracks': [t['title'] for t in tracks_of(rel)], 'hit': hits})
    return out[:25]


# ---------- HTTP ----------
class H(BaseHTTPRequestHandler):
    server_version = 'Fountain/1.0'

    def log_message(self, *a):
        pass

    def send(self, code, obj=None, ctype='application/json', raw=None):
        body = raw if raw is not None else json.dumps(obj).encode()
        self.send_response(code)
        self.send_header('Content-Type', ctype)
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type, X-Docent-Pin, ngrok-skip-browser-warning')
        self.end_headers()

    def docent(self):
        pin = self.headers.get('X-Docent-Pin', '')
        return bool(DOCENT_PIN) and hmac.compare_digest(pin, DOCENT_PIN)

    def json_body(self):
        n = int(self.headers.get('Content-Length') or 0)
        if n > 20000:
            return None
        try:
            return json.loads(self.rfile.read(n) or b'{}')
        except ValueError:
            return None

    def relay_icecast(self, path):
        try:
            up = urllib.request.urlopen(urllib.request.Request(ICECAST_URL + path, headers={'User-Agent': UA}), timeout=15)
        except urllib.error.HTTPError as e:
            return self.send(e.code, {'error': 'Icecast says ' + str(e.code)})
        except Exception:
            return self.send(502, {'error': 'Icecast is not running.'})
        with up:
            self.send_response(200)
            for k in ('Content-Type', 'Cache-Control', 'icy-name', 'icy-description', 'icy-br', 'icy-genre'):
                if up.headers.get(k):
                    self.send_header(k, up.headers[k])
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            try:
                while chunk := up.read(8192):
                    self.wfile.write(chunk)
                    self.wfile.flush()
            except (BrokenPipeError, ConnectionResetError):
                pass  # listener left

    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if ICECAST_PATHS.fullmatch(u.path):
            return self.relay_icecast(u.path)
        q = {k: v[0] for k, v in urllib.parse.parse_qs(u.query).items()}
        if u.path in ('/', '/book'):
            return self.send(200, ctype='text/html; charset=utf-8', raw=(HERE / 'static' / 'book.html').read_bytes())
        if u.path == '/docent':
            return self.send(200, ctype='text/html; charset=utf-8', raw=(HERE / 'static' / 'docent.html').read_bytes())
        if u.path == '/fountain-config.js':  # the website's copy sets the service address; here it's same-origin
            return self.send(200, ctype='text/javascript', raw=b'')
        if u.path == '/api/now':
            return self.send(200, now())
        if u.path == '/api/letters':
            return self.send(200, letters_for(q.get('artist'), q.get('album'), q.get('song')))
        if u.path == '/api/search':
            return self.send(200, search(q.get('q', '')))
        if u.path == '/api/release':
            rel = release(int(q.get('id', 0) or 0)) if q.get('id', '').isdigit() else None
            return self.send(200, {'tracks': [t['title'] for t in tracks_of(rel)]} if rel else {'tracks': []})
        if u.path == '/api/pending':
            if not self.docent():
                return self.send(401, {'error': 'Wrong PIN.'})
            with db() as c:
                rows = c.execute("select * from letters where status='pending' order by created").fetchall()
            return self.send(200, [letter_out(r) for r in rows])
        self.send(404, {'error': 'Not found'})

    def do_POST(self):
        u = urllib.parse.urlparse(self.path)
        d = self.json_body()
        if d is None:
            return self.send(400, {'error': 'Bad request'})
        if u.path == '/api/letters':
            return self.send(*add_letter(d, self.client_address[0]))
        if not self.docent():
            return self.send(401, {'error': 'Wrong PIN.'})
        if u.path == '/api/now':
            if d.get('mode') == 'auto':
                n = now() | {'source': 'auto'}
                set_now(n)
                return self.send(200, n)
            rel = release(int(d.get('release_id') or 0))
            if not rel:
                return self.send(404, {'error': 'That record is not in the crate.'})
            n = card(rel, d.get('song') or (tracks_of(rel)[0]['title'] if tracks_of(rel) else ''), 'manual')
            set_now(n)
            return self.send(200, n)
        m = re.fullmatch(r'/api/letters/([0-9a-f]{12})/(approve|reject)', u.path)
        if m:
            with db() as c:
                c.execute('update letters set status=? where id=?', ('ok' if m[2] == 'approve' else 'rejected', m[1]))
            return self.send(200, {'ok': True})
        self.send(404, {'error': 'Not found'})


def seed_demo():
    p = HERE / 'demo_crate.json'
    crate = json.loads(p.read_text())
    (DATA / 'collection.json').write_text(json.dumps([
        {'id': r['id'], 'title': r['title'], 'year': r['year'], 'artist': r['artists'][0]['name'], 'thumb': None}
        for r in crate]))
    for r in crate:
        (DATA / 'releases' / f"{r['id']}.json").write_text(json.dumps(r))
    if now().get('source') == 'none':
        set_now(card(crate[0], tracks_of(crate[0])[0]['title'], 'manual'))


if __name__ == '__main__':
    import sys
    if sys.argv[1:2] == ['import-csv'] and len(sys.argv) == 3:
        print(f'imported {len(import_csv(sys.argv[2]))} records into {DATA / "collection.json"}')
        sys.exit()
    if DEMO:
        seed_demo()
    if not DOCENT_PIN:
        log('warning: DOCENT_PIN not set, so the docent page is locked')
    threading.Thread(target=sync_collection, daemon=True).start()
    threading.Thread(target=recognizer, daemon=True).start()
    log(f'listening on http://localhost:{PORT}  (approval {"on" if REQUIRE_APPROVAL else "off"})')
    ThreadingHTTPServer(('', PORT), H).serve_forever()
