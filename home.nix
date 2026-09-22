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

  # wofi-power's per-entry icons (see home.packages below). Papirus is an
  # app-icon theme -- it has no system-lock-screen/log-out/reboot/
  # shutdown icons at all (confirmed: empty search across Papirus-Dark,
  # and its own Inherits=breeze-dark fallback ships as an empty stub,
  # zero files). Adwaita's symbolic set has these, but they're baked
  # solid-fill SVGs (#2e3436, confirmed by reading the raw files) meant
  # to be recolored via GTK's symbolic-icon-aware loader -- wofi's dmenu
  # img: syntax just rasterizes a file directly (gdk_pixbuf_new_from_file,
  # confirmed via wofi.c source), no recoloring, so as shipped they'd
  # render near-black and be invisible against a dark pill. Recolored
  # once here to solid white instead.
  powerIcons = pkgs.runCommand "wofi-power-icons" { } ''
    mkdir -p $out
    recolor() {
      ${pkgs.gnused}/bin/sed -E 's/fill="#[0-9a-fA-F]{6}"/fill="#ffffff"/' "$1" > "$2"
    }
    recolor ${pkgs.adwaita-icon-theme}/share/icons/Adwaita/symbolic/status/system-lock-screen-symbolic.svg $out/lock.svg
    recolor ${pkgs.adwaita-icon-theme}/share/icons/Adwaita/symbolic/actions/system-log-out-symbolic.svg $out/logout.svg
    recolor ${pkgs.adwaita-icon-theme}/share/icons/Adwaita/symbolic/actions/system-reboot-symbolic.svg $out/reboot.svg
    recolor ${pkgs.adwaita-icon-theme}/share/icons/Adwaita/symbolic/actions/system-shutdown-symbolic.svg $out/shutdown.svg
  '';

  # Picks a random wallpaper and applies it -- self-contained (kills +
  # relaunches hyprpaper itself, matching wallpaper-picker's pattern)
  # rather than relying on a caller to also launch hyprpaper, since this
  # now runs from two different contexts: hyprland.lua's autostart
  # (first launch, nothing running yet -- pkill is a harmless no-op) and
  # the random-wallpaper-timer systemd unit below (session already
  # running, needs the actual kill+relaunch to make the change visible).
  # Bound here (not inline in home.packages) so the systemd service can
  # reference its exact store path directly, same reasoning as the
  # existing quickshell systemd user service already does.
  randomWallpaperScript = pkgs.writeShellScriptBin "random-wallpaper" ''
    wallpaper_dir="$HOME/Pictures/wallpapers"
    runtime_conf="$HOME/.cache/hypr/hyprpaper-runtime.conf"

    [ -d "$wallpaper_dir" ] || exit 0

    candidates=()
    for f in "$wallpaper_dir"/*.jpg "$wallpaper_dir"/*.jpeg "$wallpaper_dir"/*.png "$wallpaper_dir"/*.webp; do
      [ -f "$f" ] || continue
      candidates+=("$f")
    done
    [ "''${#candidates[@]}" -gt 0 ] || exit 0

    path="''${candidates[RANDOM % ''${#candidates[@]}]}"

    ${pkgs.coreutils}/bin/mkdir -p "$(${pkgs.coreutils}/bin/dirname "$runtime_conf")"
    ${pkgs.coreutils}/bin/printf '%s\n' \
      "splash = false" \
      "wallpaper {" \
      "    monitor =" \
      "    path = $path" \
      "    fit_mode = cover" \
      "}" > "$runtime_conf"

    ${pkgs.procps}/bin/pkill -x hyprpaper 2>/dev/null
    sleep 0.2
    ${pkgs.hyprpaper}/bin/hyprpaper -c "$runtime_conf" &
    disown

    ${pkgs.matugen}/bin/matugen image "$path" --mode dark

    apply-colors "$path"
  '';

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
    tumbler # Thunar delegates all thumbnailing (image previews, etc.) to this D-Bus service -- no previews without it

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
    grim # screenshot capture, see screenshot-region below
    slurp # region selector for screenshot-region
    wl-clipboard # wl-copy/wl-paste, used by screenshot-region and cliphist
    cliphist # clipboard history, see clipboard-picker below

    # Wayland equivalent of the lock-screen script above (that one's
    # xset/i3lock calls are X11-only) -- same intent: screens never time
    # out while active/unlocked, only while actually locked, and only
    # after a delay, not immediately. hyprlock blocks in the foreground
    # until unlocked; the background timer turns monitors off 2 minutes
    # later, but only if it hasn't already been killed by an unlock
    # happening first. `dpms on` after hyprlock exits covers the case
    # where the screens already went off and the user is unlocking from
    # a dark screen (input should wake them anyway, but this is
    # deterministic rather than relying on it).
    #
    # Classic `hyprctl dispatch dpms off` doesn't work on this Lua-config
    # build -- confirmed earlier (a different dispatcher, but the same
    # failure class): hyprctl's own CLI-to-Lua bridge dumps multi-word
    # dispatch args as an unquoted, comma-less Lua call
    # (`hl.dispatch(name arg)`), which is invalid Lua syntax whenever the
    # dispatcher takes an argument at all. `hyprctl eval` calling the
    # native `hl.dsp.dpms(...)` binding directly is what's confirmed
    # working (tested live via the harmless dpms "on" no-op case).
    (writeShellScriptBin "hyprlock-timeout" ''
      (
        sleep 120
        ${hyprland}/bin/hyprctl eval 'hl.dsp.dpms("off")'
      ) &
      timer_pid=$!

      ${hyprlock}/bin/hyprlock

      kill "$timer_pid" 2>/dev/null
      ${hyprland}/bin/hyprctl eval 'hl.dsp.dpms("on")'
    '')

    # wofi equivalent of power-menu above, bound to $mainMod+M in
    # hyprland.lua. Lock uses hyprlock-timeout above, not the lock-screen
    # script above (that one's xset/i3lock calls are X11-only).
    (writeShellScriptBin "wofi-power" ''
      entries=$(${coreutils}/bin/printf '%s\n' \
        "img:${powerIcons}/lock.svg:text:Lock" \
        "img:${powerIcons}/logout.svg:text:Logout" \
        "img:${powerIcons}/reboot.svg:text:Reboot" \
        "img:${powerIcons}/shutdown.svg:text:Shutdown")

      choice=$(printf '%s' "$entries" | ${wofi}/bin/wofi -dmenu --allow-images -p "Power")
      [ -n "$choice" ] || exit 0

      label=$(printf '%s' "$choice" | ${gnused}/bin/sed -n 's/^img:.*:text:\(.*\)$/\1/p')
      case "$label" in
        Lock) hyprlock-timeout ;;
        Logout) ${hyprland}/bin/hyprctl dispatch exit ;;
        Reboot) ${systemd}/bin/systemctl reboot ;;
        Shutdown) ${systemd}/bin/systemctl poweroff ;;
      esac
    '')

    # Regenerates colors from ~/.config/hypr/colors.css (already written
    # by matugen -- see ./hyprland/matugen/) into every app that needs a
    # live push rather than just re-reading a file on its own next
    # launch, plus repoints hyprlock's background at whichever wallpaper
    # is now current ($1). Shared between hyprland.lua's autostart (after
    # the session's default-wallpaper matugen run, passing that default
    # wallpaper's path) and wallpaper-picker below (after each new pick,
    # passing the newly picked path), so both paths apply everything
    # identically.
    (writeShellScriptBin "apply-colors" ''
      wallpaper_path="$1"
      colors_css="$HOME/.config/hypr/colors.css"
      [ -f "$colors_css" ] || exit 0

      get_color() {
        ${gnused}/bin/sed -n "s/^@define-color $1 \(#[0-9a-fA-F]\{6\}\);/\1/p" "$colors_css"
      }

      accent=$(get_color accent)
      accent2=$(get_color accent2)

      # Pill borders: always on, across every waybar module (see
      # ./waybar/style.css's @import of this same file), colored from the
      # current wallpaper's accent so it always matches the theme.
      # @define-color here (not a raw hex passed to alpha()) matches the
      # @name + alpha(@name, N) pattern already used everywhere else in
      # this file/colors.css.
      pill_border_css="$HOME/.config/hypr/pill-border.css"
      if [ -n "$accent" ]; then
        ${coreutils}/bin/printf '%s\n' \
          "@define-color pill_border_accent $accent;" \
          "#workspaces, #tray, #clock, #cpu, #memory, #temperature, #network, #pulseaudio, #custom-screenshot, #custom-clipboard {" \
          "  border: 2px solid alpha(@pill_border_accent, 0.6);" \
          "  border-radius: 999px;" \
          "  background-clip: border-box;" \
          "}" > "$pill_border_css"
      else
        : > "$pill_border_css"
      fi

      # hyprlock's wallpaper: a full `background { }` block (path + a
      # light blur), sourced by the static hyprlock.conf's `source =`
      # line -- kept in ~/.cache (not overwriting hyprlock.conf itself,
      # which is a read-only home-manager store symlink).
      if [ -n "$wallpaper_path" ]; then
        hyprlock_conf="$HOME/.cache/hypr/hyprlock-wallpaper.conf"
        ${coreutils}/bin/mkdir -p "$(${coreutils}/bin/dirname "$hyprlock_conf")"
        ${coreutils}/bin/printf '%s\n' \
          "background {" \
          "    monitor =" \
          "    path = $wallpaper_path" \
          "    color = rgba(25, 20, 20, 1.0)" \
          "    blur_passes = 2" \
          "    blur_size = 4" \
          "    noise = 0.0117" \
          "    contrast = 0.8916" \
          "    brightness = 0.8172" \
          "    vibrancy = 0.1696" \
          "    vibrancy_darkness = 0.0" \
          "}" > "$hyprlock_conf"
      fi

      # Hyprland's active border, applied immediately, no restart needed.
      # `hyprctl keyword` (the flat-string classic syntax) flatly refuses
      # to run on a Lua-config setup ("keyword can't work with non-legacy
      # parsers. Use eval." -- confirmed live), and `eval` itself rejects
      # the flat "rgba(...) rgba(...) 45deg" string too -- it needs the
      # same Lua table shape hyprland.lua's own general.col.active_border
      # uses (colors array + angle), not a plain string. Confirmed live
      # via `hyprctl getoption general:col.active_border` actually
      # reflecting the new gradient after this exact call.
      if [ -n "$accent" ] && [ -n "$accent2" ]; then
        ${hyprland}/bin/hyprctl eval \
          "hl.config({ general = { col = { active_border = { colors = {\"rgba(''${accent#\#}ee)\", \"rgba(''${accent2#\#}ee)\"}, angle = 45 } } } })" \
          >/dev/null 2>&1
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
        "splash = false" \
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

      apply-colors "$path"
    '')

    randomWallpaperScript

    # Region-select screenshot, bound to $mainMod+S in hyprland.lua and
    # the custom/screenshot waybar module (./hyprland/waybar/shared.jsonc).
    # slurp with no output means the user pressed Escape to cancel --
    # exit quietly rather than taking a screenshot of nothing selected.
    (writeShellScriptBin "screenshot-region" ''
      dir="$HOME/Pictures/Screenshots"
      ${coreutils}/bin/mkdir -p "$dir"

      geometry=$(${slurp}/bin/slurp)
      [ -n "$geometry" ] || exit 0

      file="$dir/screenshot-$(${coreutils}/bin/date +%Y%m%d-%H%M%S).png"
      ${grim}/bin/grim -g "$geometry" "$file"
      ${wl-clipboard}/bin/wl-copy < "$file"
      ${libnotify}/bin/notify-send -i "$file" "Screenshot saved" "$file"
    '')

    # Clipboard history picker, bound to $mainMod+V in hyprland.lua and
    # the custom/clipboard waybar module (main monitor only, see
    # ./hyprland/waybar/config.jsonc) -- reads from cliphist's own
    # history (populated by the `wl-paste --watch cliphist store`
    # autostart process in hyprland.lua), not the live clipboard.
    (writeShellScriptBin "clipboard-picker" ''
      choice=$(${cliphist}/bin/cliphist list | ${wofi}/bin/wofi -dmenu -p "Clipboard")
      [ -n "$choice" ] || exit 0
      printf '%s' "$choice" | ${cliphist}/bin/cliphist decode | ${wl-clipboard}/bin/wl-copy
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
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
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

  # Re-randomizes the wallpaper every 30 minutes (Hyprland session only --
  # PartOf graphical-session.target the same way quickshell is above, so
  # it doesn't fire outside a live session). The actual work (matugen,
  # apply-colors, hyprpaper kill+relaunch) all lives in
  # randomWallpaperScript itself (see the top of this file) -- this unit
  # just calls it on a timer, same script hyprland.lua's autostart uses
  # for the initial pick.
  systemd.user.services.random-wallpaper-timer = {
    Unit = {
      Description = "Randomize the wallpaper";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      # KillMode=process (not the default control-group): random-wallpaper
      # backgrounds+disowns hyprpaper before exiting, but `disown` only
      # detaches it from the shell's own job control, not from systemd's
      # cgroup tracking. With the default KillMode, systemd kills every
      # process left in the service's cgroup the moment the oneshot
      # script itself exits -- including that just-launched, disowned
      # hyprpaper -- so the "new" wallpaper process was being silently
      # killed a moment after starting. Confirmed live: hyprpaper's own
      # startup log printed, then `pgrep hyprpaper` came back empty.
      # KillMode=process only ever tracks/kills the main script PID,
      # letting the backgrounded child actually survive.
      KillMode = "process";
      # random-wallpaper itself calls `apply-colors` by bare name -- fine
      # when Hyprland's own exec_cmd spawns it (inherits the session's
      # full PATH), but a systemd --user service's PATH is much more
      # restricted by default and wouldn't otherwise find it (same class
      # of issue as greetd's PATH fix in configuration.nix).
      Environment = "PATH=${config.home.profileDirectory}/bin:/run/current-system/sw/bin";
      ExecStart = "${randomWallpaperScript}/bin/random-wallpaper";
    };
  };

  systemd.user.timers.random-wallpaper-timer = {
    Unit.Description = "Randomize the wallpaper every 30 minutes";
    Timer = {
      OnUnitActiveSec = "30min";
      OnStartupSec = "30min";
    };
    Install.WantedBy = [ "timers.target" ];
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
  # fastfetch/config.jsonc is deliberately NOT deployed here anymore --
  # matugen's fastfetch_config template (./hyprland/matugen/) now owns
  # that file entirely, regenerated on every login/wallpaper change, same
  # as colors.css/kitty's colors.conf.

  # --- Hyprland session ---
  # Hyprland 0.55+ defaults to Lua config (hyprlang/.conf is deprecated).
  xdg.configFile."hypr/hyprland.lua".source = ./hyprland/hyprland.lua;
  xdg.configFile."hypr/hyprpaper.conf".source = ./hyprland/hyprpaper.conf;
  xdg.configFile."hypr/hyprlock.conf".source = ./hyprland/hyprlock.conf;
  xdg.configFile."waybar/config.jsonc".source = ./hyprland/waybar/config.jsonc;
  xdg.configFile."waybar/shared.jsonc".source = ./hyprland/waybar/shared.jsonc;
  xdg.configFile."waybar/style.css".source = ./hyprland/waybar/style.css;
  xdg.configFile."wofi/style.css".source = ./hyprland/wofi/style.css;
  xdg.configFile."wofi/config".source = ./hyprland/wofi/config;
  # config.toml + the template are versioned; the *generated* colors.css
  # they produce (~/.config/hypr/colors.css) deliberately isn't deployed
  # here -- matugen needs to write there at runtime (hyprland.lua's
  # autostart), and a file this deploys would be a read-only store
  # symlink matugen couldn't overwrite.
  xdg.configFile."matugen/config.toml".source = ./hyprland/matugen/config.toml;
  xdg.configFile."matugen/templates/colors.css".source = ./hyprland/matugen/templates/colors.css;
  xdg.configFile."matugen/templates/kitty-colors.conf".source = ./hyprland/matugen/templates/kitty-colors.conf;
  xdg.configFile."matugen/templates/fastfetch-config.jsonc".source = ./hyprland/matugen/templates/fastfetch-config.jsonc;
  xdg.configFile."kitty/kitty.conf".source = ./hyprland/kitty/kitty.conf;
  xdg.configFile."swaync/config.json".source = ./hyprland/swaync/config.json;
  xdg.configFile."swaync/style.css".source = ./hyprland/swaync/style.css;
}
