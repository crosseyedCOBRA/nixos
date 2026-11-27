#!/usr/bin/env sh
# Used by quickshell's workspace pills to switch tags by clicking.
# Usage: view-tag.sh <output-name> <tag-name>
# In dwl, dwlmsg (../home/dwl.nix) views the tag on that output (tags
# count from 0 there).
if pgrep -x dwl >/dev/null; then exec dwlmsg -o "$1" -s -t "$(( $2 - 1 ))"; fi
