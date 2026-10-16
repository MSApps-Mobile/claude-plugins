# mac-gpu-congestion — Claude plugin by MSApps

Diagnose and relieve GPU congestion on Apple Silicon Macs (M1 and later): stuttering, dropped frames, choppy scrolling, laggy video calls, fans spinning with nothing open, WindowServer eating CPU.

## What it does

- **Measures before it touches anything.** Two bundled scripts read GPU utilization and GPU memory from `ioreg`, with no `sudo`.
- **Attributes the load.** Lists the GPU client processes, the connected displays and the Metal shader cache size.
- **Tells you when it is not the GPU.** On Apple Silicon the GPU shares one memory pool with everything else, and the most common finding is memory pressure, not the GPU.
- **Relieves least-destructive-first**, then re-measures. It asks before quitting any app that may hold unsaved work.

## Installation

```bash
/plugin marketplace add MSApps-Mobile/claude-plugins
/plugin install mac-gpu-congestion@msapps-plugins
```

In Cowork: Settings → Plugins → Marketplaces → Add → `MSApps-Mobile/claude-plugins`, then install **mac-gpu-congestion**.

## Usage

```
/mac-gpu-congestion:gpu-check [symptom, e.g. 'video call is laggy']

# Examples:
/mac-gpu-congestion:gpu-check
/mac-gpu-congestion:gpu-check my Zoom call stutters on the external display
/mac-gpu-congestion:gpu-check fans are loud and scrolling in Chrome is choppy
```

You can also just say "my Mac is laggy" or "the GPU is maxed"; the skill triggers on its own.

## Requirements

- macOS on Apple Silicon (M1 or later)
- No API keys, no network access, no `sudo`

## Safety

Read-only measurement by default. Any relief step that quits an app, or restarts WindowServer, is proposed and confirmed with you first. Nothing leaves your machine.

## License

MIT
