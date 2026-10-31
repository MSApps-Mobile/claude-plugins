#!/bin/bash
# nightly learnings sync
cd "$HOME/repo" && git add -A && git commit -qm "learnings" && git push
