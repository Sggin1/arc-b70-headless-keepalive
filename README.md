# Arc Pro B70 with no active display (Headless): keeping the model on the card

**Problem:** an Arc Pro B70 used only for compute (no display active on it) lets a loaded model fall out of its
dedicated memory about 70 to 80 seconds after the last request. See
[IGCIT #1593](https://github.com/IGCIT/Intel-GPU-Community-Issue-Tracker-IGCIT/issues/1593).

## Solutions

1. **Plug a monitor into the Arc.**
2. **Dummy display plug, with its display active (extended) in Windows.** Search "DisplayPort dummy plug" (the
   author's figure: under $10; check the current price). A plug that is attached but disabled in Windows did not help.
3. **No plug: run the small script `keepalive.ps1`,** which sends the model server a one-token request every 5 seconds.

Worked on one Windows machine with one small model; details and limits are in [TESTS.md](TESTS.md). The author reports
using an earlier version of the script for several weeks; that original was lost and `keepalive.ps1` is a rewrite.

## How to run

**Dummy plug:** plug it into one of the Arc's DisplayPort outputs. In Windows open Settings > System > Display, select
the new display, and set "Multiple displays" to **Extend these displays**. A low resolution is fine. Don't leave it
disabled.

**Script.** Needs Windows PowerShell 5.1 (built in; PowerShell 7 not tested) and a llama.cpp `llama-server` already
running on `127.0.0.1` with no API key. Other servers were not tested.

1. Start your model with `llama-server` as usual and note the port (for example `--port 8084`).
2. Open a second terminal: press Start, type `PowerShell`, press Enter.
3. Go to the folder with the script, for example `cd C:\path\to\arc-b70-headless-keepalive`.
4. Run it with the same port:

```powershell
powershell -ExecutionPolicy Bypass -File .\keepalive.ps1 -Port 8084
```

It prints one line and then stays quiet unless a request fails. Leave the window open while you use the model; press
Ctrl+C or close the window to stop. `-IntervalSec 10` changes the 5-second default. If Windows blocks a downloaded
copy, run `Unblock-File .\keepalive.ps1` first.
