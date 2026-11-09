# Setting up the stream on a Windows computer

Four programs, in the order they connect:

```
turntable → BUTT → Icecast (port 8000) → letter book service (port 8787) → ngrok → the internet
```

The letter book service passes the stream through, so one ngrok address carries both the audio and the letter book. The site plays `https://malika-unflaky-loan.ngrok-free.dev/stream.aac`.

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
4. Keep Windows from touching the sound. Open the classic **Sound** control panel (Start, type `mmsys.cpl`), go to the **Recording** tab, and open your turntable interface (it may be called *Microphone, USB Audio CODEC*):
   - **Advanced:** note the **Default Format**, for example *2 channel, 16 bit, 48000 Hz*. BUTT's samplerate must match it.
   - **Advanced** (or **Enhancements**): turn off **audio enhancements**, if the tab offers them.
   - **Levels:** set it to about **75**, and adjust later in step 7.
5. In BUTT, open **Settings**:
   - **Main → Server → ADD:**
     - Type **Icecast**
     - Address `127.0.0.1`, Port `8000`
     - Password: your source password
     - Mountpoint `stream.aac` (or `stream.mp3` if you stream MP3), User `source`
   - **Audio:**
     - Device: your turntable interface
     - Channel mode **Stereo**
     - Samplerate: **the same number as Windows' Default Format** (usually **48000Hz**)
     - Streaming codec **AAC**, Bitrate **256k**. If BUTT says *Could not find aac library*, either add AAC support as its manual describes, or choose **MP3** at **320k** with the mountpoint `stream.mp3`; the launcher and the site accept either. If the gear icon next to the codec offers a profile, pick **AAC-LC**. The other profiles (HE-AAC or AAC+) are meant for low bitrates and sound worse at 256k.
6. In **Main**, tick **Start streaming after launch** if your BUTT has it, so the launcher's BUTT starts streaming by itself. Click **Save**.
7. Press **▶** (play) and play the loudest part of a record. The meters should peak around **-6 dB** and never sit in the yellow and red near 0. If they do, the sound is clipping: lower the Windows **Levels** from step 4, or your preamp's gain.

**Check:** http://localhost:8000 now lists `/stream.aac`. Open http://localhost:8000/stream.aac and you should hear the record.

The site plays `/stream.aac`. The letter book's recognition listens to `/stream.aac`, or `/stream.mp3` if that's what is live.

## 3. Python and the letter book

1. Install Python from **python.org/downloads**. The Python install manager asks a few questions; answer **y** to each. Then open a **new** terminal and check that `py -V` prints a version.
2. Get this repo onto the computer. Either:
   - install Git for Windows and run `git clone https://github.com/andrew-crena/from-a-fountain`, or
   - on GitHub, click **Code → Download ZIP** and unzip it.
3. In the `server` folder, copy `fountain.env.example` to **`fountain.env`** and fill it in:
   - `DISCOGS_TOKEN`: discogs.com → Settings → Developers → **Generate new token**
   - `AUDD_TOKEN`: optional, leave it blank. Songs are recognized through Shazam, which the launcher installs the first time it runs. An AudD token (audd.io, paid) is only a backup for when Shazam fails.
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

Double-click **`server\start-fountain.bat`**, or a copy of it on your Desktop: it finds the `server` folder by itself. It goes on air in order and checks each link before moving on:

1. **Icecast**: starts it and waits for port 8000.
2. **BUTT**: opens it and waits until Icecast actually receives `/stream.aac`. If BUTT hasn't started streaming on its own, the launcher asks it to; if that doesn't work either, it tells you to press ▶ and waits up to two minutes.
3. **Letter book service**: the first time, installs Shazam song recognition (`py -m pip install shazamio`, about a minute); then starts the service and waits for port 8787. If it isn't set up on this computer (no Python or no `server` folder), the launcher skips it and sends the stream straight from Icecast; the music still reaches the site, without "now playing" or the letter book.
4. **ngrok**: starts the tunnel on `malika-unflaky-loan.ngrok-free.dev`, or, if your ngrok sign-in can't use that address, on `cuddly-doe-adversely.ngrok-free.app`. The website tries both.
5. **On air check**: requests the stream from the public address, the way a listener would, then opens **andrew-crena.github.io/fountain/** in your browser.

Each program runs in its own minimised window. Anything already running is left alone, so it is safe to double-click twice. If a step fails, the launcher stops there and says what to check; fix it and run it again.

**If Windows blocks it** ("Windows protected your PC", or nothing happens): right-click the file, choose **Properties**, tick **Unblock** at the bottom, click OK, then double-click again. Windows marks files that arrived in a download, and unblocking clears that mark.

If a step prints `NOT FOUND`, that program is installed somewhere the launcher doesn't look. Start it by hand and run the launcher again; it will skip what's already up.

**To go off air**, double-click **`server\stop-fountain.bat`**. It closes BUTT, ngrok, the letter book service and Icecast. Letters are saved as they are written.

**Checks** (the launcher does the first one for you):
- https://malika-unflaky-loan.ngrok-free.dev/stream.aac plays.
- https://malika-unflaky-loan.ngrok-free.dev/api/now shows what's spinning, or `{"source": "none"}`.
- https://malika-unflaky-loan.ngrok-free.dev/docent asks for your PIN.
- andrew-crena.github.io/fountain/ plays when you tap **Listen**, and the **Letter book** page shows what's spinning.

## Every set after this

Double-click `start-fountain.bat`. When the window says **ON AIR**, you are live. Afterwards, double-click `stop-fountain.bat`.

## Back up the book

The letters live in `server\data\fountain.db`. Copy that file somewhere safe now and then. If you move to another computer, copy the whole `server\data` folder across.
