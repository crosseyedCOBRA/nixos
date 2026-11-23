# ZarisWM's shell (bar, launcher, OSD, Control Center, settings window) and
# WM config, from the zaris flake input's shell/ folder (see shell/README.md
# there). Copied into ~/.config once, not linked: the shell writes its
# settings back there (~/.config/quickshell/*.json), and zaris.conf and
# start-zaris.sh are meant to be edited. To start over from the repo
# version, delete ~/.config/zaris/.from-zaris-repo and rebuild (the old
# ~/.config/quickshell and ~/.config/zaris get moved aside first).
{ lib, pkgs, inputs, ... }:

let
  shell = "${inputs.zaris}/shell";
in
{
  # Password prompts for privileged GUI actions (mounting drives in Thunar,
  # NetworkManager, ...): zaris.conf starts this, since nothing else does
  # in this session. A command rather than a path, as polkit_gnome keeps
  # its agent in libexec/, which isn't linked into the profile.
  home.packages = [
    (pkgs.writeShellScriptBin "polkit-agent" ''
      # Matches the agent itself (its path is the command), not any
      # command line that merely mentions it.
      pgrep -f '^[^ ]*/libexec/polkit-gnome-authentication-agent-1' >/dev/null && exit 0
      exec ${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
    '')
  ];

  home.activation.zarisShell = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    cfg="$HOME/.config"
    if [ ! -e "$cfg/zaris/.from-zaris-repo" ]; then
      stamp=$(date +%Y%m%d-%H%M%S)
      for d in quickshell zaris; do
        [ -e "$cfg/$d" ] && run mv "$cfg/$d" "$cfg/$d.bak-$stamp"
        run mkdir -p "$cfg/$d"
        run cp -r --no-preserve=mode,ownership "${shell}/$d/." "$cfg/$d/"
      done
      run chmod +x "$cfg"/zaris/*.sh
      run install -Dm644 "${shell}/rofi/theme.rasi" "$cfg/rofi/theme.rasi"
      # Its own dunst config, so it doesn't replace Awesome's
      # (~/.config/dunst/dunstrc, from home-manager).
      run install -Dm644 "${shell}/dunst/dunstrc" "$cfg/zaris/dunstrc"

      # This machine's X driver (amdgpu) names the outputs DisplayPort-0..2
      # and HDMI-A-0, where the repo's start-zaris.sh uses modesetting's
      # DP-1..3 and HDMI-1. Same monitors, same order.
      run sed -i -E \
        -e 's/\bDP-1\b/DisplayPort-0/g' -e 's/\bDP-2\b/DisplayPort-1/g' \
        -e 's/\bDP-3\b/DisplayPort-2/g' -e 's/\bHDMI-1\b/HDMI-A-0/g' \
        "$cfg/zaris/start-zaris.sh"
      # The HDMI mirror starts off, as in Awesome; Super+D toggles it.
      run sed -i -E 's/--output HDMI-A-0 --mode [^\\]*--same-as DisplayPort-0/--output HDMI-A-0 --off/' \
        "$cfg/zaris/start-zaris.sh"
      run sed -i \
        -e 's|^exec-once=dunst$|exec-once=dunst -config ~/.config/zaris/dunstrc\nexec-once=polkit-agent|' \
        -e 's|^bind=SUPER,L,exec,i3lock$|&\nbind=SUPER,D,exec,toggle-hdmi # HDMI mirror of the main monitor on/off|' \
        -e 's|~/Pictures/cosmic.jpg|~/.config/wallpapers/cosmic.jpg|' \
        "$cfg/zaris/zaris.conf"

      run touch "$cfg/zaris/.from-zaris-repo"
    fi
  '';
}
