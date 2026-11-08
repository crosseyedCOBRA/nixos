# Awesome session (home side): its helper scripts, bar (quickshell), rofi,
# picom, dunst, clipboard history and config files. Colors follow the
# wallpaper like Hyprland's: ../awesome/bin/awesome-colors renders them with
# matugen (../awesome/matugen/) into files each of these reads. Imported first in ../home.nix so its part of
# home.packages keeps its place at the front of the combined list.
{ config, lib, pkgs, inputs, ... }:

let
  # Fallback wallpaper, before the first random pick (and for its colors,
  # see home.activation.awesomeColors).
  wallpaper = ../assets/wallpaper.jpg;

  # ../awesome/bin/ (awesome-colors, lock-screen, ...), packaged like
  # Hyprland's ../hyprland/bin/ (see ./hyprland.nix): tools by bare name,
  # from the session's PATH.
  awesomeScripts = map
    (name: pkgs.writeScriptBin name (builtins.readFile (../awesome/bin + "/${name}")))
    (builtins.attrNames (builtins.readDir ../awesome/bin));
in
{
  home.packages = with pkgs; [
    inputs.quickshell.packages.${pkgs.system}.default
    libnotify
    playerctl
    brightnessctl
    pavucontrol
    pulseaudio # provides pactl, used by the volume keybindings (../awesome/rc.lua)
    flameshot
    xclip
    feh
    thunar
    tumbler # Thunar delegates all thumbnailing (image previews, etc.) to this D-Bus service -- no previews without it
    imagemagick # lock-screen's blurred background, awesome-wallpaper-picker's thumbnails
    jq # notification-history reads dunst's history as JSON

    (writeShellScriptBin "toggle-hdmi" ''
      # Toggles HDMI-A-0 (which normally mirrors DisplayPort-0) on/off.
      if ${xrandr}/bin/xrandr --query | grep -q "^HDMI-A-0 connected [0-9]"; then
        ${xrandr}/bin/xrandr --output HDMI-A-0 --off
      else
        ${xrandr}/bin/xrandr --output HDMI-A-0 --mode 1920x1080 --rate 60 --rotate normal --same-as DisplayPort-0
      fi
    '')

    polkit_gnome # password prompts; started by its XDG autostart entry in the X session

    (writeShellScriptBin "power-menu" ''
      choice=$(printf 'Lock\nLogout\nSuspend\nReboot\nShutdown' | \
        ${rofi}/bin/rofi -dmenu -p "Power" -theme-str 'listview { lines: 5; }')
      case "$choice" in
        Lock) lock-screen ;;
        Logout) ${awesome}/bin/awesome-client 'awesome.quit()' ;;
        Suspend) ${systemd}/bin/systemctl suspend ;;
        Reboot) ${systemd}/bin/systemctl reboot ;;
        Shutdown) ${systemd}/bin/systemctl poweroff ;;
      esac
    '')
  ] ++ awesomeScripts;

  programs.alacritty = {
    enable = true;
    settings = {
      # Rendered from the wallpaper by awesome-colors; alacritty reloads it
      # on change.
      general.import = [ "~/.config/alacritty/colors.toml" ];
      window = {
        opacity = 0.95;
        padding = {
          x = 10;
          y = 10;
        };
      };
      font = {
        normal = {
          family = "JetBrainsMono Nerd Font";
          style = "Regular";
        };
        size = 10;
      };
    };
  };

  programs.rofi = {
    enable = true;
    settings = {
      terminal = "${pkgs.alacritty}/bin/alacritty";
      font = "JetBrainsMono Nerd Font 11";
    };
    theme =
      let
        inherit (config.lib.formats.rasi) mkLiteral;
      in
      {
        # The color variables used below (bg, surface, fg, accent, ...):
        # rendered from the wallpaper by awesome-colors.
        "@import" = "${config.home.homeDirectory}/.cache/awesome/rofi-colors.rasi";

        "*" = {
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "@fg";

          margin = mkLiteral "0px";
          padding = mkLiteral "0px";
          spacing = mkLiteral "0px";
        };

        window = {
          background-color = mkLiteral "@bg";
          border = mkLiteral "2px";
          border-color = mkLiteral "@accent";
          border-radius = mkLiteral "10px";
          width = mkLiteral "600px";
          location = mkLiteral "center";
        };

        mainbox = {
          padding = mkLiteral "16px";
          spacing = mkLiteral "12px";
          children = map mkLiteral [ "inputbar" "listview" ];
        };

        inputbar = {
          background-color = mkLiteral "@surface";
          border-radius = mkLiteral "8px";
          padding = mkLiteral "10px 12px";
          spacing = mkLiteral "8px";
          children = map mkLiteral [ "prompt" "entry" ];
        };

        prompt = {
          text-color = mkLiteral "@accent";
        };

        entry = {
          text-color = mkLiteral "@fg";
          placeholder = "Search...";
          placeholder-color = mkLiteral "@fg-muted";
        };

        listview = {
          background-color = mkLiteral "transparent";
          lines = 8;
          spacing = mkLiteral "4px";
          scrollbar = false;
          fixed-height = false;
        };

        element = {
          background-color = mkLiteral "transparent";
          text-color = mkLiteral "@fg-muted";
          padding = mkLiteral "8px 10px";
          border-radius = mkLiteral "6px";
        };

        element-icon = {
          size = mkLiteral "1.2em";
          vertical-align = mkLiteral "0.5";
        };

        element-text = {
          vertical-align = mkLiteral "0.5";
          text-color = mkLiteral "inherit";
        };

        "element selected" = {
          background-color = mkLiteral "@accent";
          text-color = mkLiteral "@bg";
        };

        "element urgent" = {
          text-color = mkLiteral "@urgent";
        };

        message = {
          background-color = mkLiteral "@surface";
          border-radius = mkLiteral "8px";
          padding = mkLiteral "8px";
        };

        textbox = {
          text-color = mkLiteral "@fg";
        };
      };
  };

  services.picom = {
    enable = true;
    backend = "glx";
    vSync = true;
    # Fading was the actual cause of a perceived lag on every redraw (even
    # something as instant as fastfetch felt like it had a delay before
    # appearing) -- confirmed by testing with fade disabled while leaving
    # everything else (shadow, vsync, backend) unchanged.
    fade = false;
    shadow = true;
    # vsync-aware frame pacing deliberately delays each render to just
    # before the next vblank to cut latency, but on this AMD/glx combo it's
    # what's actually reintroducing the same perceived redraw lag on
    # bursty output like fastfetch -- disable it the same way fade was
    # disabled above, leaving vsync itself (tear-free) on.
    extraArgs = [ "--no-frame-pacing" ];
    # Tooltips/menus/dnd previews are small, short-lived popups -- a full
    # drop shadow on them (the default) looks oversized and out of place,
    # most noticeably as a heavy box around Zen's context menus and
    # tooltips. Kept out of `shadowExclude` (which would also strip
    # shadows from normal windows matching a rule) since wintypes lets us
    # target just these transient window types.
    wintypes = {
      tooltip = { shadow = false; };
      utility = { shadow = false; };
      dnd = { shadow = false; };
      popup_menu = { opacity = 1.0; shadow = false; };
      dropdown_menu = { opacity = 1.0; shadow = false; };
    };
    settings = {
      corner-radius = 6;
      # Square corners on the quickshell bar, which spans each monitor's full
      # width -- rounded, the wallpaper showed through at its far ends.
      rounded-corners-exclude = [ "window_type = 'dock'" ];
    };
  };
  # Started by rc.lua rather than graphical-session.target, which Hyprland
  # reaches too -- there picom found XWayland's compositor already running
  # and failed, restarting forever.
  systemd.user.services.picom.Install.WantedBy = lib.mkForce [ ];
  # The picom package's XDG autostart entry, which the X session runs, would
  # start a second picom that holds the screen before this unit's.
  xdg.configFile."autostart/picom.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=picom
    Hidden=true
  '';
  # Nor Blueman's tray icon: Bluetooth Manager (blueman-manager) is still in
  # the app launcher, and services.blueman stays on for it.
  xdg.configFile."autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Blueman Applet
    Hidden=true
  '';

  services.dunst = {
    enable = true;
    settings = {
      global = {
        follow = "mouse";
        width = 300;
        height = 300;
        origin = "top-right";
        offset = "10x50";
        frame_width = 2;
      };
      urgency_normal = {
        timeout = 6;
      };
    };
  };
  # swaync.service (Hyprland's notification daemon) claims the same
  # notifications bus name, and systemd refuses to load either unit while
  # both do. dunst doesn't need it: rc.lua starts it with the session, so
  # it's already holding the name before anything sends a notification.
  # BusName can't be unset, so it names dunst's own control interface
  # (dunstctl's) instead, which nothing else claims.
  systemd.user.services.dunst.Service = {
    Type = lib.mkForce "simple";
    BusName = lib.mkForce "org.dunstproject.cmd0";
  };

  # Clipboard history (Super+C, the bar's clipboard button), shown in rofi.
  # X11 only, so rc.lua starts clipmenud rather than graphical-session.target
  # (Hyprland has its own, cliphist).
  services.clipmenu = {
    enable = true;
    launcher = "rofi";
  };
  systemd.user.services.clipmenu.Install.WantedBy = lib.mkForce [ ];

  # Awesome's matugen config and templates (see awesome-colors).
  xdg.configFile."matugen/awesome.toml".source = ../awesome/matugen/config.toml;
  xdg.configFile."matugen/awesome/templates".source = ../awesome/matugen/templates;

  # Colors for the fallback wallpaper, so rofi (which @imports its colors
  # file and errors without it), dunst and the rest have some before the
  # first awesome-colors run. Never overwrites colors from a real run.
  home.activation.awesomeColors = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ ! -e "$HOME/.cache/awesome/rofi-colors.rasi" ]; then
      run ${pkgs.matugen}/bin/matugen image -q -m dark --source-color-index 0 \
        -c "$HOME/.config/matugen/awesome.toml" ${wallpaper} </dev/null
    fi
  '';

  xdg.cacheFile."awesome/.keep".text = "";

  # Managed as a systemd unit so that `home-manager switch` restarts it
  # automatically whenever shell.qml or the quickshell package changes,
  # without needing to log out. Not `WantedBy = [ "graphical-session.target" ]`
  # since Awesome's own rc.lua is what starts/restarts it (see the tag-state
  # export + restart trigger there), matching the pattern of a supervised
  # service that recovers automatically if it ever dies mid-session.
  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell status bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${inputs.quickshell.packages.${pkgs.system}.default}/bin/quickshell -p %h/.config/quickshell/shell.qml";
      Restart = "on-failure";
    };
  };

  xdg.configFile."quickshell/shell.qml".source = ../quickshell/shell.qml;
  xdg.configFile."quickshell/nix-snowflake-white.svg".source = ../assets/nix-snowflake-white.svg;
  xdg.configFile."awesome/rc.lua".source = ../awesome/rc.lua;
  xdg.configFile."awesome/theme.lua".source = ../awesome/theme.lua;
  xdg.configFile."awesome/wallpaper.jpg".source = wallpaper;
  xdg.configFile."quickshell/awesome-view-tag.sh" = {
    source = ../awesome/view-tag.sh;
    executable = true;
  };
}
