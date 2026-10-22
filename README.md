# from-a-fountain

Live vinyl stream page (`index.html`), plus a small service that shows what's spinning and keeps a letter book of listeners' memories.

## The letter book service (`server/`)

One Python file, standard library only (Python 3.9+). Run it on the computer next to Icecast. **New Windows computer? Follow [SETUP-WINDOWS.md](SETUP-WINDOWS.md).**

```bash
DISCOGS_TOKEN=...  AUDD_TOKEN=...  DOCENT_PIN=...  python3 server/fountain.py
```

It then:

- **Recognizes the record.** About every 60 s it grabs ~10 s of the MP3 stream and asks AudD what it is.
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
| `AUDD_TOKEN` | | AudD API token. Without it, recognition is off and you set records by hand |
| `ICECAST_URL` | `http://localhost:8000` | Where Icecast runs |
| `STREAM_URL` | `ICECAST_URL` + `/stream.mp3` | What recognition listens to |
| `RECOGNIZE_EVERY` | `60` | Seconds between checks (each check is one AudD request) |
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

The service passes Icecast's `/stream.mp3`, `/stream.ogg` and `/status-json.xsl` through, so point ngrok at the service (port 8787) and the same address serves the stream and the letter book. `ICECAST_URL` (default `http://localhost:8000`) says where Icecast is.

### Hooking up the radio page

Put the service's address in `index.html`:

```html
data-api-url="https://your-book-address"
```

The radio then shows a "Now spinning" line that links to the letter book.
