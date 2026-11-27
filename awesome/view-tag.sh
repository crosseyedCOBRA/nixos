#!/usr/bin/env sh
# Used by quickshell's workspace pills to switch tags by clicking.
# Usage: view-tag.sh <output-name> <tag-name>
# In dwm, dwm-view-tag (../home/dwm.nix) does it; in dwl, dwlmsg
# (../home/dwl.nix) views the tag on that output (tags count from 0 there).
if pgrep -x dwm >/dev/null; then exec dwm-view-tag "$1" "$2"; fi
if pgrep -x dwl >/dev/null; then exec dwlmsg -o "$1" -s -t "$(( $2 - 1 ))"; fi
