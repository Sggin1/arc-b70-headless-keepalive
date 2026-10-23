# Arc Pro B70 with no active display: keeping the model on the card

**Problem:** an Arc Pro B70 used only for compute (no active display on it) lets a loaded model fall out of its
dedicated memory about 70 to 80 seconds after the last request. See
[IGCIT #1593](https://github.com/IGCIT/Intel-GPU-Community-Issue-Tracker-IGCIT/issues/1593).

## Fixes that worked here

1. **Dummy display plug, with its display active (extended) in Windows.** The model stayed on the card for a full
   6 min 18 s with no requests (run G). A plug that was attached but disabled in Windows did not help (runs A, C, F).
2. **No plug: a one-token request every 5 seconds.** The model stayed on the card in both runs (B, E).

```powershell
.\keepalive.ps1 -Port 8084      # llama-server must be running; -IntervalSec to change
```

The author reports using an earlier version of this script for several weeks (a report, not measured here). That
original was lost; `keepalive.ps1` is a rewrite, tested only in runs B and E below.

## Test setup

Windows 10 22H2 (19045.7807), i9-12900K, ASUS PRIME Z790-V WIFI, 31.8 GB RAM. Arc Pro B70 on driver 32.0.101.9150
(compute only); RTX 5060 Ti drives the desktop. llama.cpp `llama-server` build 10930 (Vulkan), model
Jan-v3_5-4B-Q4_K_M (2.5 GB), flags `-ngl 99 --device Vulkan1 -c 4096`. A dummy plug was attached to the Arc in every run.

## Results

Sampled every 5 s by `watch_arc.ps1` (Arc dedicated memory, available RAM, Windows screen list).

| Run | Nudge | Extended display | Result |
| --- | --- | --- | --- |
| A | no | off | 3.03 GB to 0.00 GB about 70 to 80 s after load |
| B | yes | off | held at 3.03 GB, 4 min 41 s |
| C | no | off | dropped about 77 s after the last request |
| D | no | on, then off (partly logged) | held about 80 s with display on; dropped about 73 s after it went off |
| E | yes | off | held at 3.07 GB, 4 min 40 s |
| F | no | off | dropped about 70 to 75 s after the last nudge |
| G | no | on, logged every sample | held at 3.32 GB for the full 6 min 18 s |

## Limits

- One machine, one small model, one driver, single runs. Not an Intel statement or a root-cause analysis.
- The plug was never physically removed. The tests compare the plug's display active vs disabled in Windows.
- A larger model was not tried (the spill fills system RAM on a 32 GB machine).
- "Shared usage" never rose, so where the memory goes is inferred: dedicated memory falls to zero as available RAM
  falls by about the model's size.
- Runs B (full), C, E and F were seen in live output and are not saved as raw logs. In
  `data/2026-10-23_runs-A-and-B-raw-sampler-output.txt`, only lines before 14:22:43 are run A; the rest is run B's server.
- Not measured: whether the offloaded model still answers correctly, the 5 s interval vs 3 s or 10 s.

## Files

`keepalive.ps1` (the periodic request), `watch_arc.ps1` (the sampler), `data/` (raw sampler output for A, B (partial), D, G).

```powershell
.\watch_arc.ps1 -Exe <llama-server.exe> -Model <model.gguf> -Device Vulkan1 -Port 8084 `
                -LogFile .\data\run.log [-Keepalive] [-Samples 36] [-Every 5]
```

Snapshot, 2026-10-23.
