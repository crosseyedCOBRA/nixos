# Stream Chat (Social Stream Ninja's dock) and Stream Alerts (Streamlabs'
# Recent Events) as app windows.
{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Social Stream Ninja's dock as its own window, chat only. Only views the session; the Social Stream app or
    # extension that logs into the platforms (the "source") runs elsewhere.
    # The dock link (or bare session ID) is read from
    # ~/.config/stream-chat/session, not kept in this (public) repo -- anyone
    # with it can read and post to the dock. A pasted link is kept whole,
    # since it can carry more than the session (e.g. &password=... when the
    # source has a session password set). First launch asks for it;
    # `stream-chat --reset` asks again. Its own Chromium profile, so it
    # shares no state with normal browsing.
    (writeShellScriptBin "stream-chat" ''
      file="''${XDG_CONFIG_HOME:-$HOME/.config}/stream-chat/session"
      [[ ''${1:-} == --reset ]] && rm -f "$file"
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
      # Follows/subs/raids are Stream Alerts' job (below), so keep them out
      # of the chat.
      saved+="&hideallevents"
      exec ${chromium}/bin/chromium \
        --user-data-dir="''${XDG_DATA_HOME:-$HOME/.local/share}/stream-chat" \
        --app="$saved"
    '')

    # Streamlabs' Recent Events feed (follows, subs, raids, bits, donations)
    # as its own window: a list that stays put, unlike the on-stream alert
    # box. It's a dashboard page behind the Streamlabs login rather than a
    # token URL, so there's nothing secret to keep out of the repo -- log in
    # once in the window and its Chromium profile keeps the session.
    (writeShellScriptBin "stream-alerts" ''
      exec ${chromium}/bin/chromium \
        --user-data-dir="''${XDG_DATA_HOME:-$HOME/.local/share}/stream-alerts" \
        --app=https://streamlabs.com/dashboard/recent-events
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
    genericName = "Streamlabs Recent Events";
    comment = "Follows, subs, raids, bits and donations from the stream";
    exec = "stream-alerts";
    icon = "notification-active";
    categories = [ "Network" "Chat" ];
  };
}
