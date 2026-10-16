---
description: Measure GPU load on this Apple Silicon Mac, find what is causing it, and relieve it safely
argument-hint: "[symptom, e.g. 'video call is laggy']"
---

Use the `mac-gpu-congestion` skill. The user's symptom: $ARGUMENTS

Measure first (`gpu-sample.sh` and `gpu-suspects.sh`), attribute the load, then propose relief least-destructive-first. Ask before quitting any app the user may have unsaved work in, and re-measure afterwards.
