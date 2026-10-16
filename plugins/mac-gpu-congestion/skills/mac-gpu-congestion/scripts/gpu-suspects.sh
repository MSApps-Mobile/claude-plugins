#!/bin/bash
# gpu-suspects.sh — rank the processes most likely to be driving GPU load.
#
# Honest caveat, and the reason this script is a *suspect list* and not a
# measurement: macOS exposes no per-process GPU counter to an unprivileged
# caller. Activity Monitor's GPU column comes from private API; ioreg carries
# no per-client attribution (verified — IOAccelerator publishes no
# IOUserClientCreator entries). So attribution has to come from knowing which
# processes are GPU clients by class, then confirming by bisection: quiet one,
# re-sample, see if the number moves.
#
# Usage: gpu-suspects.sh

set -uo pipefail

echo "=== KNOWN GPU CLIENTS RUNNING NOW ==="
echo "(CPU% is a proxy, not GPU load — use it to rank, not to convict)"
echo

# Process-name patterns that are GPU clients by design: the compositor, browser
# and Electron GPU helpers, video/ML pipelines, and macOS's own media daemons.
PATTERN='WindowServer|GPU Process|GPUProcess|gpu-process|WebKit.GPU|Chrome Helper \(GPU\)|Helper \(GPU\)|Electron|Code Helper|Slack Helper|Discord Helper|Figma|figma_agent|obs|OBS|zoom|Zoom|Teams|Final Cut|Compressor|Motion|DaVinci|Blender|Xcode|Simulator|ollama|llama|mlx|ComfyUI|Stable|VTDecoderXPCService|mediaanalysisd|photoanalysisd|photolibraryd|QuickLook|Preview|Photos|AVConference|screencapture|ScreenCaptureKit|Wallpaper|Dock'

printf "%-8s %-7s %-7s %-10s %s\n" "PID" "CPU%" "MEM%" "RSS_MB" "PROCESS"
# Drop ps's own header BEFORE sorting. Sorting first is a trap: "PID" sorts as
# zero numerically, so the real header lands mid-table while the busiest
# process gets promoted to row 1 and silently eaten by an NR==1 header rule —
# which hides exactly the process you are hunting for.
ps -Aceo pid,pcpu,pmem,rss,comm 2>/dev/null \
  | tail -n +2 \
  | grep -E "$PATTERN" \
  | sort -k2 -rn \
  | head -20 \
  | awk '{printf "%-8s %-7s %-7s %-10.0f %s\n", $1, $2, $3, $4/1024, substr($0, index($0,$5))}'

echo
echo "=== TOP CPU CONSUMERS OVERALL (context) ==="
printf "%-8s %-7s %-10s %s\n" "PID" "CPU%" "RSS_MB" "PROCESS"
ps -Aceo pid,pcpu,rss,comm -r 2>/dev/null | tail -n +2 | head -8 \
  | awk '{printf "%-8s %-7s %-10.0f %s\n", $1,$2,$3/1024, substr($0, index($0,$4))}'

echo
echo "=== DISPLAY LOAD ==="
# Every attached display, and especially every scaled/HiDPI mode, costs the
# compositor real GPU work every frame. A high-refresh 5K panel on a laptop GPU
# is a legitimate cause of congestion with no runaway process to blame.
system_profiler SPDisplaysDataType 2>/dev/null \
  | grep -E "Resolution|UI Looks like|Display Type|Main Display|Mirror|Connection Type" \
  | sed 's/^ */  /'

echo
echo "=== METAL SHADER CACHE ==="
# Note the path: it is NOT ~/Library/Caches/com.apple.metal (that does not
# exist). The real cache lives under the per-user Darwin cache dir.
MTL="$(getconf DARWIN_USER_CACHE_DIR 2>/dev/null)com.apple.metal"
if [ -d "$MTL" ]; then
  du -sh "$MTL" 2>/dev/null | awk '{printf "  %s  %s\n", $1, $2}'
else
  echo "  (no metal cache found at $MTL)"
fi
