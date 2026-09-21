{ config, pkgs, username, inputs, ... }:

let
  wallpaper = ./assets/wallpaper.jpg;

  # Palette pulled from assets/wallpaper.jpg (deep space navy, nebula
  # blue/purple, warm cloud orange, coral planet surface).
  colors = {
    bg = "#0a0e1a";
    bgAlt = "#14162a";
    surface = "#1a1b26";
    border = "#292e42";
    text = "#c0caf5";
    muted = "#565f89";
    blue = "#7aa2f7";
    purple = "#9d7cd8";
    orange = "#ff9e64";
    pink = "#f7768e";
  };

in
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";

  home.packages = with pkgs; [
    inputs.quickshell.packages.${pkgs.system}.default
    libnotify
    playerctl
    brightnessctl
    pavucontrol
    pulseaudio # provides pactl, used by the volume keybindings below
    flameshot
    xclip
    feh
    thunar

    (writeShellScriptBin "toggle-hdmi" ''
      # Toggles HDMI-A-0 (which normally mirrors DisplayPort-0) on/off.
      if ${xrandr}/bin/xrandr --query | grep -q "^HDMI-A-0 connected [0-9]"; then
        ${xrandr}/bin/xrandr --output HDMI-A-0 --off
      else
        ${xrandr}/bin/xrandr --output HDMI-A-0 --mode 1920x1080 --rate 60 --rotate normal --same-as DisplayPort-0
      fi
    '')

    polkit_gnome
    (writeShellScriptBin "polkit-agent" ''
      exec ${polkit_gnome}/libexec/polkit-gnome-authentication-agent-1
    '')

    # Screens otherwise never blank (DPMS/screensaver are disabled at
    # Awesome startup, see rc.lua) -- this is the one place DPMS gets
    # turned back on, for exactly as long as the session is locked, so
    # the monitors do still sleep, just only while locked. i3lock itself
    # is installed system-wide by `programs.i3lock.enable` in
    # configuration.nix (required for it to actually authenticate).
    (writeShellScriptBin "lock-screen" ''
      ${xset}/bin/xset s on
      ${xset}/bin/xset dpms 30 30 30
      ${i3lock}/bin/i3lock --nofork
      ${xset}/bin/xset s off
      ${xset}/bin/xset -dpms
    '')

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

    # --- Hyprland session (./hyprland/) ---
    kitty
    wofi
    waybar
    hyprpaper
    hyprlock
    matugen # wallpaper -> ~/.config/hypr/colors.css, see ./hyprland/matugen/
    swaynotificationcenter # notification daemon, no Wayland/layer-shell support in dunst (Awesome's daemon)

    # wofi equivalent of power-menu above, bound to $mainMod+M in
    # hyprland.lua. Lock uses hyprlock directly, not the lock-screen
    # script above (that one's xset/i3lock calls are X11-only).
    (writeShellScriptBin "wofi-power" ''
      choice=$(printf 'Lock\nLogout\nSuspend\nReboot\nShutdown' | \
        ${wofi}/bin/wofi -dmenu -p "Power")
      case "$choice" in
        Lock) ${hyprlock}/bin/hyprlock ;;
        Logout) ${hyprland}/bin/hyprctl dispatch exit ;;
        Suspend) ${systemd}/bin/systemctl suspend ;;
        Reboot) ${systemd}/bin/systemctl reboot ;;
        Shutdown) ${systemd}/bin/systemctl poweroff ;;
      esac
    '')

    # Regenerates colors from ~/.config/hypr/colors.css (already written
    # by matugen -- see ./hyprland/matugen/) into every app that needs a
    # live push rather than just re-reading a file on its own next
    # launch. Shared between hyprland.lua's autostart (after the
    # session's default-wallpaper matugen run) and wallpaper-picker
    # below (after each new pick), so both paths apply colors identically.
    (writeShellScriptBin "apply-colors" ''
      colors_css="$HOME/.config/hypr/colors.css"
      [ -f "$colors_css" ] || exit 0

      get_color() {
        ${gnused}/bin/sed -n "s/^@define-color $1 \(#[0-9a-fA-F]\{6\}\);/\1/p" "$colors_css"
      }

      accent=$(get_color accent)
      accent2=$(get_color accent2)

      # Hyprland's active border: `hyprctl keyword` applies a config
      # value immediately, no restart/reload needed -- the value syntax
      # is the same gradient format hyprland.lua's general.col.active_border
      # uses, just as a flat string instead of a Lua table.
      if [ -n "$accent" ] && [ -n "$accent2" ]; then
        ${hyprland}/bin/hyprctl keyword general:col.active_border \
          "rgba(''${accent#\#}ee) rgba(''${accent2#\#}ee) 45deg" >/dev/null 2>&1
      fi

      # waybar's nix package wraps the real binary (bin/waybar execs into
      # bin/.waybar-wrapped to set GTK_PATH/XDG_DATA_DIRS/etc) -- the
      # kernel sets the process's comm name from the *wrapped* binary
      # after that exec, so `pkill -x waybar` never matches it and the
      # old bar (stale colors) is left running alongside a new one.
      # `pkill -f` matches the full command line instead, which always
      # contains "waybar" (it's in the nix store path itself) regardless
      # of what the wrapper does to comm/argv.
      ${procps}/bin/pkill -f waybar 2>/dev/null
      ${waybar}/bin/waybar &
      disown

      # kitty: each running instance listens on its own PID-scoped remote
      # control socket (kitty.conf's listen_on unix:/tmp/kitty-{kitty_pid}).
      # -a applies to every window in that instance, -c also persists it
      # as the configured colors so new tabs/windows opened after this
      # match too, without needing colors.conf to be re-included.
      for sock in /tmp/kitty-*; do
        [ -S "$sock" ] || continue
        ${kitty}/bin/kitty @ --to "unix:$sock" set-colors -a -c "$HOME/.config/kitty/colors.conf" >/dev/null 2>&1
      done

      # swaync: style.css @imports the same colors.css waybar/wofi do, so
      # a plain CSS reload (no restart) is enough to pick up new colors.
      ${swaynotificationcenter}/bin/swaync-client --reload-css >/dev/null 2>&1
    '')

    # Bound to $mainMod+W in hyprland.lua. hyprpaper (this version) has no
    # live IPC/reload -- confirmed by reading its source, it has no
    # socket listener or signal handler at all, unlike what its own wiki
    # implies -- so swapping wallpaper means kill + relaunch against a
    # freshly-written config, not an in-place command. Written to a
    # separate runtime config rather than overwriting
    # ~/.config/hypr/hyprpaper.conf, since that one's a home-manager
    # store symlink this can't write to anyway, and this keeps every
    # session's *first* wallpaper (via hyprland.lua's autostart)
    # deterministic regardless of whatever was last picked here.
    (writeShellScriptBin "wallpaper-picker" ''
      wallpaper_dir="$HOME/Pictures/wallpapers"
      runtime_conf="$HOME/.cache/hypr/hyprpaper-runtime.conf"

      [ -d "$wallpaper_dir" ] || exit 0

      entries=""
      for f in "$wallpaper_dir"/*.jpg "$wallpaper_dir"/*.jpeg "$wallpaper_dir"/*.png "$wallpaper_dir"/*.webp; do
        [ -f "$f" ] || continue
        # No :text: label segment -- confirmed by reading wofi's own
        # parse_images()/wofi_dmenu_exec() (src/wofi.c, modes/dmenu.c):
        # a bare `img:<path>` entry is valid on its own (just no label
        # widget gets created), and dmenu mode prints the raw selected
        # line back unmodified, so plain `img:<path>` round-trips fine.
        # Command substitution strips trailing newlines, so the
        # separator has to be appended *outside* of it.
        entries="$entries$(printf 'img:%s' "$f")"$'\n'
      done
      [ -n "$entries" ] || exit 0

      # columns/image_size make this a wide image grid instead of wofi's
      # default single-column vertical list, so wallpapers are actually
      # previewable at a glance rather than a tiny 32px-tall scrolling
      # list (confirmed via wofi.5's documented config keys).
      choice=$(printf '%s' "$entries" | ${wofi}/bin/wofi -dmenu --allow-images -p "Wallpaper" \
        -W 960 -H 640 --define columns=4 --define image_size=200)
      [ -n "$choice" ] || exit 0

      path=$(printf '%s' "$choice" | ${gnused}/bin/sed -n 's/^img:\(.*\)$/\1/p')
      [ -n "$path" ] && [ -f "$path" ] || exit 0

      ${coreutils}/bin/mkdir -p "$(${coreutils}/bin/dirname "$runtime_conf")"
      ${coreutils}/bin/printf '%s\n' \
        "wallpaper {" \
        "    monitor =" \
        "    path = $path" \
        "    fit_mode = cover" \
        "}" > "$runtime_conf"

      ${procps}/bin/pkill -x hyprpaper 2>/dev/null
      sleep 0.2
      ${hyprpaper}/bin/hyprpaper -c "$runtime_conf" &
      disown

      ${matugen}/bin/matugen image "$path" --mode dark

      apply-colors
    '')
  ];

  home.sessionVariables = {
    EDITOR = "vim";
    GTK_THEME = "Adwaita:dark";
  };

  # `xsession.enable` is deliberately left off (it would also generate an
  # unconditional ~/.xsession that hijacks every login-screen session choice
  # back into i3 — see the multi-session setup below). But every session's
  # generic launch script still sources ~/.xprofile if present, so recreate
  # just that one piece by hand: without it, home.sessionVariables (EDITOR,
  # GTK_THEME, QT_QPA_PLATFORMTHEME, etc.) never reach the session's actual
  # process tree, only systemd-managed services like quickshell.
  home.file.".xprofile".text = ''
    . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
  '';

  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    colorScheme = "dark";
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style.name = "adwaita-dark";
  };

  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    settings.user = {
      name = "crosseyedCOBRA";
      email = "crosseyedcobra@gmail.com";
    };
  };

  programs.alacritty = {
    enable = true;
    settings = {
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
    terminal = "${pkgs.alacritty}/bin/alacritty";
    font = "JetBrainsMono Nerd Font 11";
    theme =
      let
        inherit (config.lib.formats.rasi) mkLiteral;
      in
      {
        "*" = {
          bg = mkLiteral colors.bg;
          bg-alt = mkLiteral colors.bgAlt;
          surface = mkLiteral colors.surface;
          border-color = mkLiteral colors.border;
          fg = mkLiteral colors.text;
          fg-muted = mkLiteral colors.muted;
          accent = mkLiteral colors.blue;
          urgent = mkLiteral colors.pink;

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
    };
  };

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

  xdg.enable = true;
  xdg.configFile."quickshell/shell.qml".source = ./quickshell/shell.qml;
  xdg.configFile."quickshell/nix-snowflake-white.svg".source = ./assets/nix-snowflake-white.svg;
  xdg.configFile."awesome/rc.lua".source = ./awesome/rc.lua;
  xdg.configFile."awesome/theme.lua".source = ./awesome/theme.lua;
  xdg.configFile."awesome/wallpaper.jpg".source = wallpaper;
  xdg.configFile."quickshell/awesome-view-tag.sh" = {
    source = ./awesome/view-tag.sh;
    executable = true;
  };
  xdg.configFile."fastfetch/config.jsonc".source = ./fastfetch/config.jsonc;

  # --- Hyprland session ---
  # Hyprland 0.55+ defaults to Lua config (hyprlang/.conf is deprecated).
  xdg.configFile."hypr/hyprland.lua".source = ./hyprland/hyprland.lua;
  xdg.configFile."hypr/hyprpaper.conf".source = ./hyprland/hyprpaper.conf;
  xdg.configFile."hypr/hyprlock.conf".source = ./hyprland/hyprlock.conf;
  xdg.configFile."waybar/config.jsonc".source = ./hyprland/waybar/config.jsonc;
  xdg.configFile."waybar/style.css".source = ./hyprland/waybar/style.css;
  xdg.configFile."wofi/style.css".source = ./hyprland/wofi/style.css;
  # config.toml + the template are versioned; the *generated* colors.css
  # they produce (~/.config/hypr/colors.css) deliberately isn't deployed
  # here -- matugen needs to write there at runtime (hyprland.lua's
  # autostart), and a file this deploys would be a read-only store
  # symlink matugen couldn't overwrite.
  xdg.configFile."matugen/config.toml".source = ./hyprland/matugen/config.toml;
  xdg.configFile."matugen/templates/colors.css".source = ./hyprland/matugen/templates/colors.css;
  xdg.configFile."matugen/templates/kitty-colors.conf".source = ./hyprland/matugen/templates/kitty-colors.conf;
  xdg.configFile."kitty/kitty.conf".source = ./hyprland/kitty/kitty.conf;
  xdg.configFile."swaync/config.json".source = ./hyprland/swaync/config.json;
  xdg.configFile."swaync/style.css".source = ./hyprland/swaync/style.css;
}
