# from-a-fountain

Live vinyl stream page (`index.html`), plus a small service that shows what's spinning and keeps a letter book of listeners' memories.

## The letter book service (`server/`)

One Python file, standard library only (Python 3.9+). Run it on the computer next to Icecast. **New Windows computer? Follow [SETUP-WINDOWS.md](SETUP-WINDOWS.md).**

```bash
pip install shazamio        # optional: song recognition through Shazam
DISCOGS_TOKEN=...  DOCENT_PIN=...  python3 server/fountain.py
```

It then:

- **Recognizes the record.** It grabs ~13 s of the stream and asks what it is, in this order:
  1. **Shazam**, through [shazamio](https://github.com/shazamio/ShazamIO), if it is installed (the Windows launcher installs it). Free, and good at short clips. It is an unofficial client of Shazam's own service, not an API Shazam offers, so it is against Shazam's terms and can stop working when Shazam changes something. Then `py -m pip install -U shazamio` usually brings it back. After 3 failures in a row it rests for 15 minutes.
  2. **AudD**, only if `AUDD_TOKEN` is set, and only when Shazam failed (a Shazam "no match" isn't re-asked).
  3. **The docent page**: set the song by hand, and the service follows the side, moving to the next track when each one should end (Discogs track lengths), then hands back to recognition when the side is over.

  Shazam is checked about every 20 seconds (`SHAZAM_EVERY`) while someone is on the site or the stream, so a new record shows within about 20 seconds; if Shazam starts refusing that many requests, it rests and you can raise the setting. AudD, which costs per request, is asked as rarely as it can:
  - after a match, it waits until that song should end (the recognizer says where in the song the clip was; Discogs, or AudD's Apple Music data, give the length), then checks the next one, so about one request per song;
  - with no match (silence, between records) it backs off to 1, 2, then 4 minutes;
  - when nobody has the site open and nobody is on the stream, it makes no requests at all, and checks as soon as someone arrives;
  - optionally, `AUDD_DAILY_LIMIT` caps AudD requests per day.
- **Matches it to your Discogs crate** (`andrew-crena`), so the page gets the right pressing: cover, label, year, where it was recorded, and the credited players.
- **Serves the letter book** at `/`: what's spinning, a prompt to write a memory about the song, album, or artist, and past letters, closest match first (same song → same album → same artist). People can also pick any record, playing or not.
- **Serves the docent page** at `/docent` (needs the PIN): set the record by hand when recognition misses (this pauses recognition until you tap "Back to automatic") and approve letters before they show.

### Loading your crate

The service pulls your collection from Discogs on start. You can also load a Discogs export (Collection → Export → CSV), which makes search work right away, even offline:

```bash
python3 server/fountain.py import-csv andrewcrena-collection.csv
```

Tracklists, covers and credits are fetched per record in the background and cached. For a reissue, credits and "recorded at" come from the original release, so your 2010 *Kind of Blue* still shows Coltrane, Evans, and the 1959 session dates.

Data lives in `server/data/` (SQLite + a Discogs cache). Back it up; that's the book.

### Settings

| Variable | Default | |
|---|---|---|
| `DISCOGS_TOKEN` | | Discogs personal access token (Settings → Developers) |
| `DISCOGS_USER` | `andrewcrena` | |
| `SHAZAM` | `1` | `0` turns Shazam recognition off |
| `SHAZAM_EVERY` | `20` | Seconds between Shazam checks while someone is on the site or the stream |
| `AUDD_TOKEN` | | AudD API token, a paid backup for when Shazam fails. Optional |
| `ICECAST_URL` | `http://localhost:8000` | Where Icecast runs |
| `STREAM_URL` | `/stream.aac`, else `/stream.mp3` | What recognition listens to |
| `RECOGNIZE_EVERY` | `180` | Seconds between checks when a song's length is unknown |
| `AUDD_DAILY_LIMIT` | `0` | Most AudD requests per day; `0` for no cap. The day's count is in the log |
| `DOCENT_PIN` | | Required for `/docent` |
| `REQUIRE_APPROVAL` | `1` | `0` shows letters right away |
| `FOUNTAIN_PORT` | `8787` | |
| `DEMO` | `0` | `1` runs with a 3-record sample crate and no outside services |

Try it without any keys: `DEMO=1 DOCENT_PIN=1234 python3 server/fountain.py`, then open http://localhost:8787 and http://localhost:8787/docent.

### On the website

`andrew-crena.github.io` hosts copies of the two pages at `/letters/` and `/docent/`, with buttons on the main menu. Its `fountain-config.js` holds the service's public address:

```js
window.FOUNTAIN_API = 'https://your-book-address';
```

When you change `server/static/book.html` or `docent.html`, copy them to `letters/index.html` and `docent/index.html` on the site.

### One public address

The service passes Icecast's `/stream.aac`, `/stream.mp3`, `/stream.ogg` and `/status-json.xsl` through, so point ngrok at the service (port 8787) and the same address serves the stream and the letter book. `ICECAST_URL` (default `http://localhost:8000`) says where Icecast is.

### Hooking up the radio page

Put the service's address in `index.html`:

```html
data-api-url="https://your-book-address"
```

The radio then shows a "Now spinning" line that links to the letter book.
