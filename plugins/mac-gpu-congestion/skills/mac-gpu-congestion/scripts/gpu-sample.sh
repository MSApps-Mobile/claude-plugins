#!/bin/bash
# gpu-sample.sh — sample Apple Silicon GPU utilization and memory, no sudo required.
#
# Why this exists: powermetrics is the "official" GPU sampler but it needs root,
# and on most machines sudo prompts for a password — which means an
# agent running unattended can't use it. IOAccelerator's PerformanceStatistics
# dict carries the same utilization counters and reads fine as a normal user.
#
# Usage: gpu-sample.sh [duration_seconds] [interval_seconds]
#        gpu-sample.sh 10 1     # default: 10 samples over 10s

set -uo pipefail

DURATION=${1:-10}
INTERVAL=${2:-1}

# A zero or negative interval would spin the loop with no delay and divide by
# zero below; fall back to 1s rather than failing in the user's face.
awk -v i="$INTERVAL" 'BEGIN { exit (i+0 > 0) ? 0 : 1 }' || INTERVAL=1

read_stats() {
  ioreg -r -d 1 -w 0 -c IOAccelerator 2>/dev/null \
    | grep -o '"PerformanceStatistics" = {[^}]*}' \
    | head -1
}

probe=$(read_stats)
if [ -z "$probe" ]; then
  echo "ERROR: no IOAccelerator PerformanceStatistics found."
  echo "This machine is probably not Apple Silicon, or ioreg is restricted."
  exit 1
fi

field() { echo "$1" | grep -o "\"$2\"=[0-9]*" | head -1 | cut -d= -f2; }

samples=""
peak_alloc=0
peak_inuse=0

# Loop a fixed number of times rather than until a wall-clock deadline.
# Learned the hard way: ioreg itself can take over a second on a loaded
# machine, so a deadline-based loop collects zero samples exactly when the
# system is busy — which is the only time anyone runs this script.
#
# Compute the count in awk, not bash arithmetic: a sub-second interval like
# 0.5 is a legitimate ask when chasing a brief stutter, and bash integer math
# would either crash on it or silently floor it to zero samples.
COUNT=$(awk -v d="$DURATION" -v i="$INTERVAL" 'BEGIN {
  if (i+0 <= 0) i = 1
  n = int(d / i)
  if (n < 1) n = 1
  print n
}')

for _ in $(seq 1 "$COUNT"); do
  s=$(read_stats)
  [ -z "$s" ] && { sleep "$INTERVAL"; continue; }

  dev=$(field "$s" "Device Utilization %")
  ren=$(field "$s" "Renderer Utilization %")
  til=$(field "$s" "Tiler Utilization %")
  alloc=$(field "$s" "Alloc system memory")
  inuse=$(field "$s" "In use system memory")

  dev=${dev:-0}; ren=${ren:-0}; til=${til:-0}; alloc=${alloc:-0}; inuse=${inuse:-0}

  samples+="$dev $ren $til"$'\n'
  [ "$alloc" -gt "$peak_alloc" ] 2>/dev/null && peak_alloc=$alloc
  [ "$inuse" -gt "$peak_inuse" ] 2>/dev/null && peak_inuse=$inuse

  sleep "$INTERVAL"
done

echo "=== GPU UTILIZATION (${COUNT} samples, ${INTERVAL}s interval) ==="
echo "$samples" | grep -v '^$' | awk '
{ n++; d+=$1; r+=$2; t+=$3
  if ($1>dmax) dmax=$1
  if ($1<dmin || n==1) dmin=$1
  if ($1>=50) busy++ }
END {
  if (n==0) { print "no samples collected"; exit }
  printf "samples          : %d\n", n
  printf "device util      : mean %.1f%%  min %d%%  max %d%%\n", d/n, dmin, dmax
  printf "renderer util    : mean %.1f%%\n", r/n
  printf "tiler util       : mean %.1f%%\n", t/n
  printf "samples >=50%%    : %d of %d (%.0f%% of window)\n", busy, n, (busy*100.0)/n
}'

echo
echo "=== GPU MEMORY (peak over window) ==="
awk -v a="$peak_alloc" -v i="$peak_inuse" 'BEGIN {
  printf "allocated        : %.2f GB\n", a/1073741824
  printf "in use           : %.2f GB\n", i/1073741824
}'

echo
echo "=== UNIFIED MEMORY CONTEXT ==="
# On Apple Silicon the GPU has no private VRAM: it eats the same pool as apps.
# A "GPU problem" is very often really a system-wide memory-pressure problem,
# so these numbers decide the verdict as much as the GPU counters do.
#
# Deliberately NOT reporting memory_pressure's "free percentage" as the
# headline: it counts inactive and speculative pages as available, so it
# cheerfully prints "24% free" on a machine with 14 MB genuinely free and
# swap pinned at its ceiling. Truly-free pages from vm_stat are the honest
# number, and swap is the honest severity signal.
vm_stat 2>/dev/null | awk '
/page size of/ { match($0,/[0-9]+/); ps=substr($0,RSTART,RLENGTH) }
/^Pages free/           { gsub(/\./,"",$3); free=$3 }
/^Pages inactive/       { gsub(/\./,"",$3); inact=$3 }
/^Pages speculative/    { gsub(/\./,"",$3); spec=$3 }
/^Pages occupied by compressor/ { gsub(/\./,"",$5); comp=$5 }
END {
  if (ps=="") ps=16384
  printf "truly free RAM     : %.2f GB   (vm_stat pages free)\n", free*ps/1073741824
  printf "reclaimable        : %.2f GB   (inactive + speculative)\n", (inact+spec)*ps/1073741824
  printf "held by compressor : %.2f GB\n", comp*ps/1073741824
}'

swapusage=$(sysctl -n vm.swapusage 2>/dev/null)
echo "swap               : ${swapusage:-unknown}"
echo "$swapusage" | awk '{
  for (i=1;i<=NF;i++) {
    if ($i=="total")  { gsub(/M/,"",$(i+2)); tot=$(i+2) }
    if ($i=="used")   { gsub(/M/,"",$(i+2)); used=$(i+2) }
  }
  if (tot>0) {
    pct = used*100.0/tot
    printf "swap pressure      : %.0f%% of ceiling", pct
    if (pct>=90) print "   <-- CRITICAL: memory is the bottleneck, not the GPU"
    else if (pct>=70) print "   <-- elevated"
    else print ""
  }
}'
