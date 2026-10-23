# Arc Pro B70: model leaves VRAM when no display is active, and a small periodic request prevents it

A snapshot from one Windows machine, October 2026. Small sample, single machine. Read the
"What this does not show" section before relying on any of it.

Related report: [IGCIT #1593](https://github.com/IGCIT/Intel-GPU-Community-Issue-Tracker-IGCIT/issues/1593)
("Arc Pro B70 headless: no display dongle offloads into system RAM").

## Summary

With an Intel Arc Pro B70 used only as a compute device (llama.cpp, Vulkan) and no active
display, the model's dedicated GPU memory dropped to zero about 70 to 80 seconds after the
last request (or after load, if no request was sent), and system RAM headroom fell by roughly the model's size at the same moment.
Sending the server a one-token request every 5 seconds kept the model on the card for the
whole run, twice. With an extended display active on the Arc, the model stayed on the card
for the duration it was active in one run.

This is an observation of the counters below, not a root-cause analysis.

## Setup (all values read from the machine)

| Item | Value |
| --- | --- |
| CPU | Intel Core i9-12900K |
| Board | ASUS PRIME Z790-V WIFI |
| RAM | 31.8 GB |
| OS | Windows 10 Pro 22H2, build 19045.7807 |
| Compute card | Intel Arc Pro B70, PCI `VEN_8086 DEV_E223`, driver 32.0.101.9150 (2026-10-07) |
| Display card | NVIDIA GeForce RTX 5060 Ti, driver 32.0.16.1742 (2026-09-29), drives the desktop |
| Server | llama.cpp `llama-server` 0.4.0-dev, build 10930, commit 56381e407, Vulkan, Clang 20.1.8 |
| Model | `Jan-v3_5-4B-Q4_K_M/model.gguf` (about 2.5 GB file) |
| Server flags | `-ngl 99 --device Vulkan1 -c 4096`, default everything else |

The Arc has a dummy plug attached (EDID manufacturer TCT, product 0270). In Windows the plug can be
shown as an extended 800x600 display or disabled. All runs below had the plug physically attached.
I have NOT tested with the plug physically removed.

## Method

`watch_arc.ps1` samples every 5 seconds: per-adapter `GPU Adapter Memory` Dedicated and Shared
usage, `Memory\Available MBytes`, and the list of Windows screens. The Arc is the adapter whose
dedicated usage rises when the model loads (LUID `0x00012ef9` in the last run; LUIDs may change
between boots). `keepalive.ps1` POSTs `{"prompt":" ","n_predict":1}` to `/completion` every
5 seconds.

Available RAM, not free RAM, is used. Windows' "free" figure excludes reclaimable file cache and
overstated memory use in the first runs.

## Results

All runs: 4B model, one machine, driver 9150, plug attached. "Off" means the extended display was
not in the Windows desktop when checked.

| Run | Nudge | Display | Result |
| --- | --- | --- | --- |
| A | no | off | Arc dedicated 3.03 GB to 0.00 GB about 70 to 80 s after load; "free" RAM (the early runs used Windows free RAM, not available RAM) fell about 2.6 GB at that moment |
| B | yes | off | held at 3.03 GB for the whole run, 4 min 41 s |
| C | no (same server as B, nudge stopped) | off | dropped to 0.00 GB about 77 s after the last request |
| D | no | on at start, off by 14:37:26, on again by 14:40:01 | held about 80 s with the display on; dropped at 14:37:53, about 73 s after the dip in memory that coincided with the display being turned off |
| E | yes | off at start and end | held at 3.07 GB for the whole run, 4 min 40 s |
| F | no (nudge from E stopped) | off | dropped to 0.00 GB about 70 to 75 s after the last nudge |

Raw sampler output that exists as files is in `data/`. Runs B (full), C, E and F were seen in live
session output and are summarised here, not saved raw. `data/2026-10-23_runs-A-and-B-raw-sampler-output.txt`
contains run A's samples; its samples from 14:22:43 onward belong to run B's server, because the two
samplers overlapped, so use only the lines before that for run A.

## What this does not show

- Plug removed. Every run had the dummy plug attached; only the Windows display state varied.
  The condition in IGCIT #1593 (no plug) is untested here.
- Run D's display state was not logged continuously. It was observed on, then off, then on. Treat
  the display-related reading as a hint, not a measurement.
- One small model (4B, 2.5 GB). A 27B or 32 GB-class model was not tried, because the spill fills
  system RAM on a 32 GB machine.
- No repeats beyond the numbers above, one machine, one driver (9150).
- "Shared usage" never rose in any run, so the counters do not show where the memory goes. Evidence
  that it moves to system RAM is circumstantial: dedicated usage falls to zero while available RAM
  falls by about the model's size.
- Whether the keepalive requests were all delivered was not confirmed from the server log; the
  server's task counter was consistent with about one request per 5 seconds.
- Whether the offloaded model still answers correctly and how slowly was not measured.
- Not an Intel statement. This is one user's observation.

## Workaround

```powershell
.\keepalive.ps1 -Port 8084          # a request every 5 s; -IntervalSec to change
```

The 5-second interval is not tuned. 3 or 10 seconds were not compared. The server must be running.

## Reproduce

```powershell
.\watch_arc.ps1 -Exe <llama-server.exe> -Model <model.gguf> -Device Vulkan1 -Port 8084 `
                -LogFile .\data\run.log [-Keepalive] [-Samples 36] [-Every 5]
```

Watch the dedicated column of the Arc's LUID. Disable any extended display on the Arc first, and
check the `screens` column to confirm it stayed disabled. The script kills `llama-server` if
available RAM drops below 5 GB.

## Files

| File | What it is |
| --- | --- |
| `keepalive.ps1` | The periodic request |
| `watch_arc.ps1` | The sampler (also logs the Windows screen list per sample) |
| `data/` | Raw sampler output for runs A, B (partial) and D |

## Status

Snapshot, 2026-10-23. To do: repeat with the plug physically removed, a larger model, more repeats,
and log the display state on every sample (the current `watch_arc.ps1` does).
