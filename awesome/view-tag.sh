#!/usr/bin/env sh
# Used by quickshell's workspace pills to switch Awesome tags by clicking.
# Usage: view-tag.sh <output-name> <tag-name>
# The same bar runs in dwm, where dwm-view-tag (../home/dwm.nix) does it.
if pgrep -x dwm >/dev/null; then exec dwm-view-tag "$1" "$2"; fi
awesome-client <<LUA
for scr in screen do
  if scr.outputs["$1"] then
    for _, t in ipairs(scr.tags) do
      if t.name == "$2" then t:view_only() end
    end
  end
end
LUA
