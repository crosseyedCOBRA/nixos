# dwl's session services and helpers (home side): the quickshell bar,
# notifications, the polkit agent and the wallpaper, started with
# dwl-session.target (../modules/dwl.nix), and the bar's link to dwl.
# Keybindings, rules, monitors and the HDMI mirror are in the dwl repo
# itself (config.h).
{ lib, pkgs, ... }:

let
  # dwl's IPC client (dwl-ipc-unstable-v2, the ipc patch in ~/src/dwl):
  # watches and sets tags and layouts. Not in nixpkgs.
  dwlmsg = pkgs.stdenv.mkDerivation {
    pname = "dwlmsg";
    version = "0-unstable-2026-09-22";
    src = pkgs.fetchgit {
      url = "https://codeberg.org/julmajustus/dwlmsg.git";
      rev = "361e983914a32c59949c0422d36605486ba8213c";
      hash = "sha256-VGc3iDFsm38gKnWbb1Aegbi46JF4PMGFUc5J/iXSjkU=";
    };
    nativeBuildInputs = with pkgs; [ pkg-config wayland-scanner ];
    buildInputs = [ pkgs.wayland ];
    makeFlags = [ "PREFIX=$(out)" ];
  };

  # dwl's state in the tags.json format the quickshell bar reads
  # (../quickshell/shell.qml, the same file dwm-bar-state writes): per
  # output the 9 tags, the layout name and whether its focused window is
  # fullscreen (the bar hides then). dwlmsg -w reports each change as a
  # flushed batch per output: "<output> tag <n> <state> <windows> <focused>"
  # for each tag (state 1 = viewed, 2 = urgent), "layout <name>",
  # "fullscreen 0|1", then a "tags ..." summary. That summary has its
  # fields mixed up (it reports the viewed tag as urgent), so only the
  # per-tag lines are read, and the summary marks the end of the batch.
  # Exits when dwl does; systemd restarts it.
  dwlBarState = pkgs.writers.writePython3Bin "dwl-bar-state" { flakeIgnore = [ "E501" ]; } ''
    import json
    import os
    import subprocess
    import sys

    out = os.path.expanduser("~/.cache/awesome/tags.json")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    state = {}


    def write():
        tmp = out + ".tmp"
        with open(tmp, "w") as f:
            json.dump(state, f, separators=(",", ":"))
        os.replace(tmp, out)


    proc = subprocess.Popen(["${dwlmsg}/bin/dwlmsg", "-w"],
                            stdout=subprocess.PIPE, text=True, bufsize=1)
    for line in proc.stdout:
        parts = line.rstrip("\n").split(" ")
        if len(parts) < 3:
            continue
        name, kind, args = parts[0], parts[1], parts[2:]
        mon = state.setdefault(name, {
            "tags": [{"name": str(i + 1), "focused": False, "urgent": False}
                     for i in range(9)],
            "layout": "", "fullscreen": False})
        if kind == "tag" and len(args) == 4:
            i, tagstate = int(args[0]), int(args[1])
            if i < 9:
                mon["tags"][i]["focused"] = tagstate == 1
                mon["tags"][i]["urgent"] = tagstate == 2
        elif kind == "layout":
            mon["layout"] = " ".join(args)
        elif kind == "fullscreen":
            mon["fullscreen"] = args[0] == "1"
        elif kind == "tags":
            write()
    sys.exit(proc.wait())
  '';

  # Services that run only in dwl, started and stopped with its session.
  inDwl = {
    Unit.PartOf = [ "dwl-session.target" ];
    Unit.After = [ "dwl-session.target" ];
    Install.WantedBy = [ "dwl-session.target" ];
  };

  # While locked only: the monitors turn off after a minute without input,
  # and any key or mouse movement wakes them (wlopm: dwl's output power
  # control; Hyprland's version uses hyprctl). Unlocked, they never blank.
  idleLocked = pkgs.writeText "dwl-hypridle-locked.conf" ''
    general {
        # Locked means away: a paused video, a game or Discord holding an
        # idle inhibitor shouldn't keep the monitors on behind the lock.
        ignore_dbus_inhibit = true
        ignore_systemd_inhibit = true
        ignore_wayland_inhibit = true
        inhibit_sleep = 0
    }

    listener {
        timeout = 60
        on-timeout = ${pkgs.wlopm}/bin/wlopm --off '*'
        on-resume = ${pkgs.wlopm}/bin/wlopm --on '*'
    }
  '';

  # Super+L and the power menu's Lock: dwl's version of Hyprland's
  # hyprlock-timeout. hyprlock with the current wallpaper and colors
  # (awesome-colors writes them to ~/.cache/hypr/).
  dwlLock = pkgs.writeShellScriptBin "dwl-lock" ''
    pgrep -x hyprlock >/dev/null && exit 0

    ${pkgs.hypridle}/bin/hypridle -c ${idleLocked} >/dev/null 2>&1 &
    idle=$!

    ${pkgs.hyprlock}/bin/hyprlock

    kill "$idle" 2>/dev/null
    # Unlocking takes a keypress, which already woke the monitors; this
    # covers hyprlock exiting some other way while they were off.
    ${pkgs.wlopm}/bin/wlopm --on '*'
  '';

  # Ends the session's services when dwl quits. nixpkgs' dwl session starts
  # dwl-session.target with dwl, but nothing stops it after: at logout the
  # bar and the rest kept restarting with no compositor until systemd gave
  # up on them, and the next login came up without a bar. dwl starts this
  # (config.h's autostart) and sends it SIGTERM at exit, waiting for it.
  dwlSessionGuard = pkgs.writeShellScriptBin "dwl-session-guard" ''
    trap 'systemctl --user stop dwl-session.target graphical-session.target; exit 0' TERM INT HUP
    while :; do sleep 3600 & wait $!; done
  '';
in
{
  home.packages = [ dwlmsg dwlBarState dwlLock dwlSessionGuard pkgs.swaybg ];

  systemd.user.services.dwl-bar-state = lib.recursiveUpdate inDwl {
    Unit.Description = "dwl state for the quickshell bar (tags.json)";
    Service = {
      ExecStart = "${dwlBarState}/bin/dwl-bar-state";
      Restart = "on-failure";
      RestartSec = 1;
    };
  };

  # A random wallpaper (and its colors) at every dwl login, like the dwm
  # session's `awesome-colors --random-once` before dwm starts. A user
  # service has no XDG_SESSION_ID, so awesome-colors picks a new one every
  # time this runs: once per login.
  systemd.user.services.dwl-random-wallpaper = lib.recursiveUpdate inDwl {
    Unit.Description = "dwl: pick a random wallpaper and colors";
    Unit.Before = [ "dwl-wallpaper.service" ];
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.runtimeShell} -c 'exec awesome-colors --random-once'";
    };
  };

  # The current wallpaper (the one awesome-colors picked last), with swaybg:
  # xwallpaper only draws on X.
  systemd.user.services.dwl-wallpaper = lib.recursiveUpdate inDwl {
    Unit.Description = "dwl wallpaper (swaybg)";
    Unit.After = [ "dwl-session.target" "dwl-random-wallpaper.service" ];
    Service = {
      ExecStart = "${pkgs.writeShellScript "dwl-wallpaper" ''
        exec ${pkgs.swaybg}/bin/swaybg -m fill -i "$(cat "$HOME/.cache/awesome/current-wallpaper")"
      ''}";
      Restart = "on-failure";
    };
  };

  # Password prompts (mounting drives, NetworkManager, ...): polkit-gnome,
  # like the X sessions. hyprpolkitagent crashes outside Hyprland (an
  # OpenGL assertion in its graphics library).
  systemd.user.services.dwl-polkit-agent = lib.recursiveUpdate inDwl {
    Unit.Description = "polkit agent for dwl (polkit-gnome)";
    Service = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart = "on-failure";
    };
  };

  # Notifications: swaync, with Hyprland's config and style
  # (../hyprland/swaync/; Super+N opens its panel). Its colors come from
  # ~/.config/hypr/colors.css, which awesome-colors renders from the
  # wallpaper too and then reloads swaync's style.
  systemd.user.services.dwl-notifications = lib.recursiveUpdate inDwl {
    Unit.Description = "dwl notifications (swaync)";
    Service = {
      ExecStart = "${pkgs.swaynotificationcenter}/bin/swaync";
      Restart = "on-failure";
    };
  };

  # Clipboard history for the bar's clipboard button and Super+C (cliphist
  # list | rofi), like Hyprland's autostart does.
  systemd.user.services.dwl-clipboard-history = lib.recursiveUpdate inDwl {
    Unit.Description = "dwl clipboard history (cliphist)";
    Service = {
      ExecStart = "${pkgs.wl-clipboard}/bin/wl-paste --watch ${pkgs.cliphist}/bin/cliphist store";
      Restart = "on-failure";
    };
  };

  # The bar (../home/awesome.nix defines it) joins the dwl session as well,
  # and stops with it.
  systemd.user.services.quickshell.Install.WantedBy = [ "dwl-session.target" ];
  systemd.user.services.quickshell.Unit.PartOf = [ "dwl-session.target" ];
}
