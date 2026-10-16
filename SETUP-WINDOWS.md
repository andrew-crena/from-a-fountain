# Setting up the stream on a Windows computer

Four programs, in the order they connect:

```
turntable → BUTT → Icecast (port 8000) → letter book service (port 8787) → ngrok → the internet
```

The letter book service passes the stream through, so one ngrok address carries both the audio and the letter book. The site's links keep working: `https://malika-unflaky-loan.ngrok-free.dev/stream.mp3`.

Set up each step and check it before moving on.

---

## 1. Icecast (the stream server)

1. Download the Windows installer from **icecast.org/download** and install it.
2. Open **`icecast.xml`** in the Icecast folder (usually `C:\Program Files (x86)\Icecast`). Open Notepad with **Run as administrator** first, or Windows won't let you save it.
3. Change these lines. Pick your own passwords; don't reuse the examples:
   ```xml
   <source-password>pick-a-source-password</source-password>
   <relay-password>pick-another</relay-password>
   <admin-password>pick-an-admin-password</admin-password>
   <hostname>malika-unflaky-loan.ngrok-free.dev</hostname>
   ```
   Leave `<port>8000</port>` as it is.
4. Open **Icecast** from the Start menu and click **Start Server**.

**Check:** http://localhost:8000 shows the Icecast status page.

## 2. BUTT (sends the turntable to Icecast)

1. Download BUTT for Windows from **danielnoethen.de/butt** and install it.
2. Plug in your turntable's audio interface or preamp.
3. Windows **Settings → Privacy & security → Microphone**: turn on **Let desktop apps access your microphone**. Without this, BUTT records silence.
4. In BUTT, open **Settings**:
   - **Main → Server → ADD:**
     - Type **Icecast**
     - Address `127.0.0.1`, Port `8000`
     - Password: your source password
     - Mountpoint `stream.mp3`, User `source`
   - **Audio:**
     - Device: your turntable interface
     - Codec **MP3**, Bitrate **320k**, Samplerate **44100**
5. Close Settings and press **▶** (play) in BUTT.

**Check:** http://localhost:8000 now lists `/stream.mp3`. Open http://localhost:8000/stream.mp3 and you should hear the record.

Optional FLAC stream: the woodgrain radio page in this repo can play lossless audio from `/stream.ogg`. The live site only uses MP3, so you can skip this. If you want it, run a second BUTT with Codec **FLAC** and Mountpoint `stream.ogg`.

## 3. Python and the letter book

1. Install Python from **python.org/downloads**. On the first screen, tick **Add python.exe to PATH**.
2. Get this repo onto the computer. Either:
   - install Git for Windows and run `git clone https://github.com/andrew-crena/from-a-fountain`, or
   - on GitHub, click **Code → Download ZIP** and unzip it.
3. In the `server` folder, copy `fountain.env.example` to **`fountain.env`** and fill it in:
   - `DISCOGS_TOKEN`: discogs.com → Settings → Developers → **Generate new token**
   - `AUDD_TOKEN`: from your dashboard at audd.io
   - `DOCENT_PIN`: any PIN you'll remember for the Docent page

   `fountain.env` stays on this computer and is never uploaded.
4. Load your crate. Open a terminal in the `server` folder and run:
   ```
   python fountain.py import-csv "C:\path\to\your-discogs-export.csv"
   ```
   This step is optional. Without it, the service downloads your collection from Discogs when it starts.

## 4. ngrok (the public address)

1. Install it. In a terminal, run `winget install ngrok.ngrok`, or download it from **ngrok.com/download**.
2. Sign in at **dashboard.ngrok.com** with the same account as before, so you keep `malika-unflaky-loan.ngrok-free.dev`. Copy your authtoken from **Your Authtoken**, then run:
   ```
   ngrok config add-authtoken YOUR_TOKEN
   ```

## 5. Start everything

1. Start Icecast (**Start Server**) and press play in BUTT.
2. Double-click **`server\start-windows.bat`**. It opens ngrok in its own window and runs the letter book service.

If ngrok says `unknown flag: --url`, you have an older ngrok. Edit the bat file and change `--url=` to `--domain=`.

**Checks:**
- https://malika-unflaky-loan.ngrok-free.dev/stream.mp3 plays.
- https://malika-unflaky-loan.ngrok-free.dev/api/now shows what's spinning, or `{"source": "none"}`.
- https://malika-unflaky-loan.ngrok-free.dev/docent asks for your PIN.
- andrew-crena.github.io plays when you tap **Listen**, and the **Letter book** page shows what's spinning.

## Every set after this

1. Icecast: **Start Server**.
2. BUTT: **▶**.
3. Double-click `start-windows.bat`.

To stop, close the bat window and the ngrok window, then stop BUTT and Icecast.

## Back up the book

The letters live in `server\data\fountain.db`. Copy that file somewhere safe now and then. If you move to another computer, copy the whole `server\data` folder across.
