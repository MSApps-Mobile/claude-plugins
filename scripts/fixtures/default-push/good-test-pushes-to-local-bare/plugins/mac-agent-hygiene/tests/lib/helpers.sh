#!/bin/bash
# helper for the tests: pushes to the throwaway bare repo
git -C "$1" push -q origin HEAD
