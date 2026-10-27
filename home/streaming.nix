# Stream Chat / Stream Alerts: Social Stream Ninja's dock as app windows.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Social Stream Ninja's dock (combined chat + follow/sub/raid alerts) as
    # its own window. Only views the session; the Social Stream app or
    # extension that logs into the platforms (the "source") runs elsewhere.
    # The dock link (or bare session ID) is read from
    # ~/.config/stream-chat/session, not kept in this (public) repo -- anyone
    # with it can read and post to the dock. A pasted link is kept whole,
    # since it can carry more than the session (e.g. &password=... when the
    # source has a session password set). First launch asks for it;
    # `stream-chat --reset` asks again. `stream-chat --alerts` opens the
    # same session with the dock's own &showonlyevents filter, so follows/
    # subs/raids/bits get a window of their own instead of scrolling past in
    # chat. Each window has its own Chromium profile, so they don't share
    # dock settings with each other or state with normal browsing.
    (writeShellScriptBin "stream-chat" ''
      file="''${XDG_CONFIG_HOME:-$HOME/.config}/stream-chat/session"
      profile=stream-chat
      for arg; do
        case $arg in
          --reset) rm -f "$file" ;;
          --alerts) profile=stream-alerts ;;
        esac
      done
      if [[ ! -s $file ]]; then
        input=$(wofi --dmenu --prompt "Dock link or session ID" -L 1 </dev/null) || exit 0
        input=''${input//[[:space:]]/}
        if [[ ! $input =~ ^https://socialstream\.ninja/.*[?\&]session= && ! $input =~ ^[A-Za-z0-9_-]+$ ]]; then
          ${libnotify}/bin/notify-send "Stream Chat" "Paste the dock link from Social Stream (or just the session ID)."
          exit 1
        fi
        mkdir -p "$(dirname "$file")"
        printf '%s\n' "$input" > "$file"
        chmod 600 "$file"
      fi
      saved=$(< "$file")
      [[ $saved == https://* ]] || saved="https://socialstream.ninja/dock.html?session=$saved"
      # Charcoal background: the dock's &chroma=<hex> sets the page color.
      # Links copied from Social Stream carry chroma=0004 (transparent, for
      # OBS), so swap whatever is there for ours.
      saved=$(sed -E 's/([?&])chroma=[^&#]*(&|$)/\1/; s/[?&]$//' <<<"$saved")
      saved+="&chroma=2B2B2B"
      # The two windows split the session between them: alerts gets only
      # events, chat gets everything but events. Both dock filters key off
      # the same data.event field, so nothing shows in both or in neither.
      if [[ $profile == stream-alerts ]]; then
        saved+="&showonlyevents"
      else
        saved+="&hideallevents"
      fi
      exec ${chromium}/bin/chromium \
        --user-data-dir="''${XDG_DATA_HOME:-$HOME/.local/share}/$profile" \
        --app="$saved"
    '')
  ];

  xdg.desktopEntries.stream-chat = {
    name = "Stream Chat";
    genericName = "Social Stream Ninja dock";
    comment = "Combined chat from the stream (alerts are in Stream Alerts)";
    exec = "stream-chat";
    icon = "internet-chat";
    categories = [ "Network" "Chat" ];
    actions.reset = {
      name = "Change session ID";
      exec = "stream-chat --reset";
    };
  };
  xdg.desktopEntries.stream-alerts = {
    name = "Stream Alerts";
    genericName = "Social Stream Ninja alerts";
    comment = "Only follows, subs, raids, bits and donations from the stream";
    exec = "stream-chat --alerts";
    icon = "notification-active";
    categories = [ "Network" "Chat" ];
  };
}
