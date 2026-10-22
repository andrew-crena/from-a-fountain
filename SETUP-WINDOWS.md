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
4. Move the log folder somewhere Icecast can write to. Windows blocks writing inside `Program Files`, and Icecast stops with `FATAL: could not open error logging (./log\error.log): Permission denied`.
   - Create the folder `C:\icecast-log`.
   - In the `<paths>` section, change `<logdir>./log</logdir>` to `<logdir>C:\icecast-log</logdir>`.
5. Save, then open **Icecast** from the Start menu and start it.

   The `report-db.xml` and `PRNG seed` warnings in Icecast 2.5 don't affect streaming. A `<hostname> not configured` warning means step 3 wasn't saved.

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
5. In **Main**, tick **Start streaming after launch** if your BUTT has it, so the launcher's BUTT starts streaming by itself. Click **Save**.
6. Close Settings and press **▶** (play) in BUTT.

**Check:** http://localhost:8000 now lists `/stream.mp3`. Open http://localhost:8000/stream.mp3 and you should hear the record.

Optional FLAC stream: the woodgrain radio page in this repo can play lossless audio from `/stream.ogg`. The live site only uses MP3, so you can skip this. If you want it, run a second BUTT with Codec **FLAC** and Mountpoint `stream.ogg`.

## 3. Python and the letter book

1. Install Python from **python.org/downloads**. The Python install manager asks a few questions; answer **y** to each. Then open a **new** terminal and check that `py -V` prints a version.
2. Get this repo onto the computer. Either:
   - install Git for Windows and run `git clone https://github.com/andrew-crena/from-a-fountain`, or
   - on GitHub, click **Code → Download ZIP** and unzip it.
3. In the `server` folder, copy `fountain.env.example` to **`fountain.env`** and fill it in:
   - `DISCOGS_TOKEN`: discogs.com → Settings → Developers → **Generate new token**
   - `AUDD_TOKEN`: from your dashboard at audd.io
   - `DISCOGS_USER`: your Discogs username (the service defaults to `andrewcrena`)
   - `DOCENT_PIN`: any PIN you'll remember for the Docent page

   `fountain.env` stays on this computer and is never uploaded.
4. Load your crate. Open a terminal in the `server` folder and run:
   ```
   py fountain.py import-csv "C:\path\to\your-discogs-export.csv"
   ```
   This step is optional. Without it, the service downloads your collection from Discogs when it starts.

## 4. ngrok (the public address)

1. Install it. In a terminal, run `winget install ngrok.ngrok`, or download it from **ngrok.com/download**.
2. Sign in at **dashboard.ngrok.com** with the same account as before, so you keep `malika-unflaky-loan.ngrok-free.dev`. Copy your authtoken from **Your Authtoken**, then run:
   ```
   ngrok config add-authtoken YOUR_TOKEN
   ```

## 5. Start everything

Double-click **`server\start-fountain.bat`**. It starts all four programs in order — Icecast, BUTT, ngrok, then the letter book — and skips any that are already running. If BUTT doesn't start streaming on its own, press ▶ in it.

**If Windows blocks it** ("Windows protected your PC", or nothing happens): right-click the file, choose **Properties**, tick **Unblock** at the bottom, click OK, then double-click again. Windows marks files that arrived in a download, and unblocking clears that mark.

If a step prints `NOT FOUND`, that program is installed somewhere the launcher doesn't look. Start it by hand and run the launcher again; it will skip what's already up.

**Checks:**
- https://malika-unflaky-loan.ngrok-free.dev/stream.mp3 plays.
- https://malika-unflaky-loan.ngrok-free.dev/api/now shows what's spinning, or `{"source": "none"}`.
- https://malika-unflaky-loan.ngrok-free.dev/docent asks for your PIN.
- andrew-crena.github.io plays when you tap **Listen**, and the **Letter book** page shows what's spinning.

## Every set after this

Double-click `start-fountain.bat`. It skips anything already running, so it is safe to run twice.

To stop, close all four windows.

## Back up the book

The letters live in `server\data\fountain.db`. Copy that file somewhere safe now and then. If you move to another computer, copy the whole `server\data` folder across.
