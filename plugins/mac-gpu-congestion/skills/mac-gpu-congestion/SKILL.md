---
name: mac-gpu-congestion
description: >
  Diagnose and relieve GPU congestion on Apple Silicon Macs — stuttering,
  dropped frames, spinning fans, anything that feels "graphically" slow.
  Measures real GPU utilization without sudo, attributes the load, relieves it
  least-destructive-first. Trigger on: "GPU congestion", "GPU cleanup", "GPU is
  maxed", "graphics are lagging", "screen stuttering", "choppy scrolling",
  "dropped frames", "janky animations", "fans spinning with nothing running",
  "WindowServer eating CPU", "Chrome is making my Mac crawl", "laggy video
  call", "external display is laggy", "Metal", "GPU memory", "ניקוי GPU",
  "המאוורר עובד חזק" — and trigger even when the user just says the Mac is
  "slow" or "laggy" in a visual or interactive way. Use BEFORE killing any
  process on a slowness complaint: the most common finding is that the GPU is
  fine and the real culprit is unified-memory pressure. Not for disk space
  (use a disk-cleanup skill) or boot/hardware triage.
metadata:
  version: "1.0.0"
  author: "MSApps"
  updated: "2026-08-14"
---

# Mac GPU Congestion — Diagnose, Then Relieve

Someone says the Mac is stuttering and asks you to "clean up the GPU." The
instinct is to start killing processes. Resist it. On Apple Silicon the GPU
shares one memory pool with everything else, so the *symptoms* of GPU
congestion, memory exhaustion, thermal throttling, and plain CPU contention
are nearly identical from the user's chair. Kill the wrong process and you
lose someone's unsaved work while the real problem keeps running.

So the shape of this skill is: **measure, attribute, relieve, verify** — in
that order, always. The measurement step is cheap (ten seconds) and it is
routinely the step that changes the answer.

## Scope

Yours: GPU utilization and GPU memory on Apple Silicon (M1 and later),
compositor/WindowServer load, Metal shader cache, display-driven GPU cost,
runaway GPU client processes, and the honest call on whether a slowness
complaint is even GPU-related.

Not yours: disk space housekeeping, whole-machine hardware and boot triage
(escalate to the user if you find panics, GPU resets, or a suspected hardware
fault), and app build pipelines.

## Step 1 — Measure before you touch anything

Run both bundled scripts. They need no sudo, which matters because
`powermetrics` — the "official" GPU sampler — requires root, and on these
machines sudo prompts for a password that an unattended agent cannot answer.

```bash
scripts/gpu-sample.sh 10 1     # 10 samples of GPU util + GPU memory
scripts/gpu-suspects.sh        # who the GPU clients are, display load, cache
```

`gpu-sample.sh` reads `IOAccelerator`'s `PerformanceStatistics` via `ioreg`,
which carries the same utilization counters powermetrics reports and reads
fine as a normal user.

Run the sample while the machine is actually misbehaving. A ten-second window
on an idle Mac tells you nothing — if the stutter is intermittent, sample
during the stutter or lengthen the window.

Sampling rate is a real variable, not a detail. Stutter is by nature bursty,
and a 1-second interval will read 0% straight through a spike that a
half-second interval catches at 20%+ — measured on this hardware, same
machine, seconds apart. When the complaint is stutter rather than sustained
slowness, sample fast (`gpu-sample.sh 10 0.5`) before concluding the GPU is
idle. An idle reading at coarse resolution is weak evidence.

## Step 2 — Read the verdict honestly

Cross the GPU numbers against the memory numbers. This table is the whole
intellectual content of the skill, because three of its four rows mean "the
GPU is not your problem":

| GPU device util | Memory free / swap | What is actually happening |
|---|---|---|
| Sustained **>60%** | healthy (free >20%, swap stable) | **Genuine GPU congestion.** Go to Step 3. |
| Sustained **>60%** | free <15%, swap growing | **Unified memory exhaustion.** The GPU is contending with swap thrash. Relieving memory usually fixes the GPU number for free. |
| **<20%** | free <15%, swap growing | **Not a GPU problem at all.** This is memory pressure that *feels* like graphics lag because the compositor is waiting on swap. Say so plainly and treat the memory. |
| **<20%** | healthy | **Not congestion.** Look at CPU contention, disk I/O, or thermals instead. Don't kill anything on GPU grounds. |

Two numbers to weigh alongside the table:

- **Swap used vs. total.** Swap near its ceiling with pageouts climbing is the
  single strongest signal that memory, not the GPU, is the bottleneck.
- **`Alloc system memory`** from the sampler is the GPU's slice of unified
  memory. A large allocation with near-zero utilization is normal — allocation
  is not consumption, so never convict a process on allocation alone.

Report the verdict before acting on it. If the answer is "your GPU is at 1%,
this is a memory problem," that finding *is* the deliverable — deliver it
rather than performing a cleanup to look busy.

## Step 3 — Attribute the load

macOS publishes no per-process GPU counter to an unprivileged caller.
Activity Monitor's GPU column comes from private API, and `ioreg` carries no
per-client attribution — verified, `IOAccelerator` publishes no
`IOUserClientCreator` entries. So attribution is inference plus a controlled
experiment, and you should say so rather than presenting a guess as a
measurement.

`gpu-suspects.sh` ranks processes that are GPU clients *by class* — the
compositor, browser and Electron GPU helpers, video decode services, ML
runtimes, media daemons. Its CPU column ranks candidates; it does not convict
them.

To actually convict a suspect, **bisect**: quiet the top candidate (close the
window, pause the render, quit the app), re-run `gpu-sample.sh`, and see
whether utilization drops. One confirmed culprit beats four plausible ones.

Two attribution notes that save time:

- **`WindowServer` high is a symptom, not a cause.** It is the compositor; it
  burns GPU because something is making it redraw. Hunt what is driving it —
  an animating window, a video, a huge scaled display — rather than blaming
  WindowServer itself.
- **Displays cost GPU with no process to blame.** Scaled/HiDPI modes, high
  refresh rates, and extra external panels all cost the compositor real work
  every frame. If the suspects list is quiet but utilization is high, look at
  the display configuration in the script's output.

## Step 4 — Relieve, least destructive first

Work down this ladder and stop as soon as the numbers recover. Every rung
costs the user more than the one above it, so earning the cheap win first is
the whole point.

1. **Quit idle GPU clients.** Extra browser windows, Preview, QuickLook,
   idle video calls. Free, instant, reversible.
2. **Kill a respawnable GPU helper.** Browser GPU processes
   (`Chrome Helper (GPU)`, `com.apple.WebKit.GPU`) respawn clean and cost the
   user nothing but a repaint. Safe rung; often sufficient.
3. **Reduce display load.** Drop to a native (unscaled) resolution, lower the
   refresh rate, or disconnect a secondary panel. Reversible and effective
   when the compositor is the load.
4. **Clear the Metal shader cache.** Only worth it if you suspect corruption
   (visual artifacts, one app misbehaving after an update) — it is not a
   general speedup, and it costs a recompile stutter on next launch. Path
   matters, see Traps.
5. **Disable hardware acceleration in the offending app.** The persistent fix
   when one app reliably drives congestion. Costs that app some smoothness.
6. **Restart WindowServer** — gated, see below.
7. **Reboot.** Honest and often correct. Don't treat it as failure.

## Hard gates — confirm with a human first

- **Never restart WindowServer without explicit confirmation.** It force-logs
  the user out immediately and destroys unsaved work in every open app. It is
  a last resort, not a troubleshooting step. Ask, name the cost, wait.
- **Never kill a process holding unsaved user work** — editors, design tools,
  video projects — without asking, however good a suspect it looks.
- **Never kill `kernel_task`.** It is the thermal governor. High
  `kernel_task` means the machine is protecting itself from heat; treat the
  heat.
- **Don't delete anything under `/System`.** Nothing there is yours to mop.

## Traps

These are verified on this hardware and each one has burned someone:

- **`powermetrics` needs root and sudo is not passwordless here.** Design
  around it — the bundled scripts already do.
- **The Metal cache is not in `~/Library/Caches`.** `~/Library/Caches/com.apple.metal*`
  does not exist. The real path is `$(getconf DARWIN_USER_CACHE_DIR)com.apple.metal`.
  Confirm it exists before clearing, and expect it to be small (single-digit
  MB) — clearing it is a correctness fix, never a space win.
- **`pmset -g therm` reports nothing on Apple Silicon.** It is largely an
  Intel-era interface. Its silence is not evidence of healthy thermals; use
  fan noise, sustained load, and `kernel_task` instead.
- **Bound every sampling command, or it will hang you.** The diagnostics in
  this area default to *continuous streams*, not one-shot queries, and an
  unattended agent blocks on them until the harness reaps the call — usually
  having learned nothing, because several print no output at all on a healthy
  machine. Two of six test agents lost a probe this way. Always use the
  bounded form:

  | Hangs forever | Use instead |
  |---|---|
  | `pmset -g thermlog` | `pmset -g therm` |
  | `top -l 0` | `top -l 1` |
  | `powermetrics` (no `-n`) | `powermetrics -n 1` (still needs root) |

  The tell is a flag that means "sample count": zero or absent means infinite.
  If you reach for a sampler this skill doesn't bundle, check that flag before
  running it.
- **Don't sample on a wall-clock deadline.** `ioreg` can take over a second
  on a loaded machine, so deadline loops collect zero samples exactly when
  the system is busy — the only time anyone runs this. The bundled sampler
  loops a fixed count for this reason.
- **Allocation ≠ utilization.** Multi-GB `Alloc system memory` at 0%
  utilization is a healthy idle GPU, not congestion.
- **`memory_pressure`'s "free percentage" lies about severity.** It counts
  inactive and speculative pages as available, so it reports a comfortable
  "24% free" on a machine with 14 MB genuinely free and swap pinned at its
  ceiling. Trust `vm_stat` pages-free and swap usage instead — the bundled
  sampler reports those for this reason.
- **`sudo purge` is not a fix.** On Apple Silicon it mostly re-thrashes the
  compressor and buys seconds. Don't reach for it.
- **One sample window is not a measurement.** Utilization on the same idle
  machine has read 32% in one window and 4.9% in the next, minutes apart.
  Sample twice before declaring a verdict either way.

## Report back

Lead with the verdict, then the evidence, then what you changed. Keep it
short — the user wants to know if their Mac is okay:

```
Verdict:  <genuine GPU congestion | memory pressure, not GPU | not congestion>
Evidence: GPU <mean>% mean / <max>% peak, GPU mem <N> GB allocated
          system memory free <N>%, swap <used>/<total>
Culprit:  <process/display, and how it was confirmed — or "none confirmed">
Actions:  <what was quit/killed/changed, or "none needed">
After:    GPU <mean>% mean  (was <mean>%)
Left for you: <anything gated or needing a human decision>
```

If nothing was wrong, say that plainly. "Your GPU is idle and this is a
memory problem" is a better outcome than a cleanup that changed nothing.

## Deeper reference

`references/relief-playbook.md` — per-app fixes (Chrome/Electron/Zoom/Figma/
video/ML runtimes), the memory-pressure treatment path for when the verdict
lands there, external-display specifics, and how to spot a GPU reset or
hardware fault worth escalating to the user. Read it when the
verdict is anything other than a clean quick win.
