# from-a-fountain

Live vinyl stream page (`index.html`), plus a small service that shows what's spinning and keeps a letter book of listeners' memories.

## The letter book service (`server/`)

One Python file, standard library only (Python 3.9+). Run it on the computer next to Icecast.

```bash
DISCOGS_TOKEN=...  AUDD_TOKEN=...  DOCENT_PIN=...  python3 server/fountain.py
```

It then:

- **Recognizes the record.** About every 60 s it grabs ~10 s of the MP3 stream and asks AudD what it is.
- **Matches it to your Discogs crate** (`andrew-crena`), so the page gets the right pressing: cover, label, year, where it was recorded, and the credited players.
- **Serves the letter book** at `/`: what's spinning, a prompt to write a memory about the song, album, or artist, and past letters, closest match first (same song → same album → same artist). People can also pick any record, playing or not.
- **Serves the docent page** at `/docent` (needs the PIN): set the record by hand when recognition misses (this pauses recognition until you tap "Back to automatic") and approve letters before they show.

Data lives in `server/data/` (SQLite + a Discogs cache). Back it up; that's the book.

### Settings

| Variable | Default | |
|---|---|---|
| `DISCOGS_TOKEN` | | Discogs personal access token (Settings → Developers) |
| `DISCOGS_USER` | `andrew-crena` | |
| `AUDD_TOKEN` | | AudD API token. Without it, recognition is off and you set records by hand |
| `STREAM_URL` | the ngrok `stream.mp3` mount | What recognition listens to |
| `RECOGNIZE_EVERY` | `60` | Seconds between checks (each check is one AudD request) |
| `DOCENT_PIN` | | Required for `/docent` |
| `REQUIRE_APPROVAL` | `1` | `0` shows letters right away |
| `FOUNTAIN_PORT` | `8787` | |
| `DEMO` | `0` | `1` runs with a 3-record sample crate and no outside services |

Try it without any keys: `DEMO=1 DOCENT_PIN=1234 python3 server/fountain.py`, then open http://localhost:8787 and http://localhost:8787/docent.

### Hooking up the radio page

The service needs its own public address (for example a second tunnel next to the Icecast one). Put it in `index.html`:

```html
data-api-url="https://your-book-address"
```

The radio then shows a "Now spinning" line that links to the letter book.
