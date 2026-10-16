# Relief Playbook

Read this once the verdict from SKILL.md Step 2 is anything other than a
clean quick win. Contents:

1. [Memory pressure path](#1-memory-pressure-path) — when the GPU is innocent
2. [Per-app relief](#2-per-app-relief) — browsers, Electron, calls, design, video, ML
3. [Display-driven congestion](#3-display-driven-congestion)
4. [Metal shader cache](#4-metal-shader-cache)
5. [WindowServer](#5-windowserver)
6. [Escalate: GPU resets and hardware fault](#6-escalate-gpu-resets-and-hardware-fault)

---

## 1. Memory pressure path

This is the most common real verdict, so treat it as a first-class outcome
rather than a dead end. On Apple Silicon there is no separate VRAM — every GB
an app holds is a GB the GPU cannot use, and once swap starts thrashing the
compositor waits on disk and the machine *feels* graphically broken.

Confirm before treating:

```bash
memory_pressure | tail -6           # free percentage
sysctl -n vm.swapusage              # used vs total — near-ceiling is the tell
vm_stat | head -8                   # pageins/pageouts climbing?
ps -Aceo pid,rss,comm -m | head -15 # biggest resident processes
```

Read swap as a *trend*, not a level. macOS uses swap freely and healthily;
what matters is swap pinned near its ceiling with pageouts still climbing.

Two things to name for the user when you find this, because both change how
urgently they should act:

- **Near the swap ceiling, macOS starts force-killing applications** to
  reclaim memory. If swap is above ~95%, tell them to save their work *first*,
  before any cleanup step.
- **Swap thrash is real SSD wear.** A thrashing day can write terabytes.
  Worth mentioning once — not as alarmism, but because it reframes "my Mac is
  a bit slow" into something worth fixing structurally.

A pattern worth recognizing: on machines that run many concurrent agent or
editor sessions, no single process looks guilty. RSS per process stays modest
precisely *because* memory has been pushed into swap, so ranking by RSS
under-reports the true cost. Count the *fleet* — total process count,
duplicate helper processes per session — rather than hunting one fat process.

Relief, cheapest first:

1. Quit the largest resident processes the user is not actively using. Ranked
   by RSS, not by name — intuitions about which app is "heavy" are often wrong.
2. Browser tabs are usually the largest reclaimable block. Closing windows
   beats killing the browser and losing session state.
3. Look for accumulated duplicate processes — long-running agent sessions,
   orphaned helpers, stale dev servers. Many identical processes at moderate
   RSS each can outweigh any single visible app.
4. Restart the worst offender rather than the whole machine if it is one app
   with a leak.
5. Reboot if swap does not recover. Legitimate when swap has been pinned for
   a long session.

Report the memory numbers even when the user asked about the GPU. They asked
about a symptom; you owe them the cause.

---

## 2. Per-app relief

### Chrome / Chromium / Edge

- Chrome's own Task Manager (Window → Task Manager) *does* show per-process
  GPU memory — one of the few places you can get real per-process attribution.
  Use it to identify the offending tab, then close that tab specifically.
- Killing `Chrome Helper (GPU)` is safe; it respawns and the window repaints.
- Persistent fix if one profile reliably drives load: turn off "Use graphics
  acceleration when available" in Settings → System. Costs some scroll
  smoothness, buys back the GPU.
- Hardware-accelerated video decode makes a background video tab a real,
  continuous GPU load. A muted autoplaying tab is a classic invisible culprit.

### Electron apps (Slack, Discord, VS Code, Figma desktop, Notion)

- Each is a browser; everything above applies.
- VS Code specifically: heavy extensions, large minimaps, and animated
  terminal output drive continuous repaint. `--disable-gpu` is available if
  one workspace is pathological.
- Check for *multiple* instances of the same Electron app — helpers orphaned
  by a crash keep rendering.

### Video calls (Zoom, Teams, Meet)

- Background blur and virtual backgrounds are ML + GPU work every frame, and
  are the single most expensive toggle in a call. Turning blur off is the
  highest-yield fix on a laggy call, by a wide margin.
- Gallery view of many participants costs far more than speaker view.
- Screen sharing while on an external display compounds both.

### Figma / design tools

- Large boards with many components re-render continuously. Closing unused
  tabs and collapsing complex frames helps immediately.
- `figma_agent` running with the app closed is safe to kill.

### Video and ML runtimes

- Export/render jobs (Final Cut, Compressor, DaVinci, ffmpeg with
  VideoToolbox) *should* saturate the GPU. That is the tool working, not
  congestion. Confirm intent before killing — you may destroy hours of render.
- Local models (`ollama`, `llama`, `mlx`, ComfyUI, Stable Diffusion) hold
  large unified-memory allocations and starve everything else. Unloading the
  model beats killing the runtime if the user still needs it.
- Apple's own `mediaanalysisd` / `photoanalysisd` run Photos library analysis
  in the background and can churn the GPU for hours after importing photos.
  They finish on their own and resume after being killed — usually best left
  alone unless the user needs the machine right now.

---

## 3. Display-driven congestion

Real GPU cost with no process to blame. Check `gpu-suspects.sh`'s display
section, then:

- **Scaled resolutions** cost extra: the Mac renders to a larger framebuffer
  and downsamples every frame. Switching to a native/default mode is the
  cheapest structural win on a laptop panel.
- **High refresh (ProMotion, 120 Hz)** doubles compositor work versus 60 Hz.
  Lowering it in Displays settings is reversible and immediately measurable.
- **Multiple / large external panels** — especially 4K and 5K over a single
  cable, or anything driven through a dock or DisplayLink adapter. DisplayLink
  in particular does compression on the host and is a known heavy CPU+GPU
  cost.
- Dynamic wallpapers and aerial screensavers (`WallpaperAerialsExtension`)
  render continuously. A static wallpaper is free.

Re-sample after each display change — this is one area where the effect is
large and instantly visible in the numbers.

---

## 4. Metal shader cache

Path, and the trap worth repeating: it is **not** in `~/Library/Caches`.

```bash
MTL="$(getconf DARWIN_USER_CACHE_DIR)com.apple.metal"
du -sh "$MTL"
```

Clear it only for suspected corruption — visual artifacts, or one app
misbehaving right after an OS or GPU-driver update. It is not a general
speedup, and it is not a disk-space win (expect single-digit MB).

```bash
rm -rf "$(getconf DARWIN_USER_CACHE_DIR)com.apple.metal"
```

Regenerates automatically. Expect a one-time recompile stutter as apps
relaunch. Quit the affected app first so it rebuilds cleanly.

---

## 5. WindowServer

WindowServer is the compositor — it is *supposed* to use GPU. High
WindowServer is a symptom of something making it redraw, so hunt the driver
of the redraw first: an animating window, a playing video, a scaled or
high-refresh display, a misbehaving app repainting in a loop.

Restarting it force-logs the user out and destroys unsaved work everywhere.
That makes it a gated action requiring explicit confirmation, never a routine
troubleshooting rung. If a human has confirmed and understands the cost:

```bash
sudo killall -HUP WindowServer     # logs out immediately; needs sudo password
```

Before proposing it, ask whether a plain reboot would serve better — same
disruption, cleaner result, and it clears memory pressure too.

---

## 6. Escalate: GPU resets and hardware fault

Some findings are past the reach of cleanup and belong to
the user:

- **`recoveryCount` climbing** in `IOAccelerator`'s `PerformanceStatistics`
  means the GPU driver has reset. Occasional resets after a bad shader happen;
  a climbing count during normal use is a real fault signal. Check it:

  ```bash
  ioreg -r -d 1 -w 0 -c IOAccelerator | grep -o '"recoveryCount"=[0-9]*'
  ```

- **Visual artifacts** — tearing, corrupted textures, colored blocks —
  especially if they survive a reboot and appear in the boot sequence.
- **Panel or display-link failures** — a display that stops enumerating, or
  fails to re-enumerate after a lid cycle. That signature points at display
  flex/hardware, not GPU load, and has its own diagnostic path.
- **Kernel panics** referencing AGX/IOAccelerator/AppleGPU.

In each case: capture the evidence, stop cleaning, and escalate. A cleanup
pass on a hardware fault wastes the user's time and can mask the signal that
would have gotten it diagnosed.
