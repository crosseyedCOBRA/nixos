{ config, lib, pkgs, username, inputs, ... }:

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

  # Helper scripts for the Hyprland session (random-wallpaper, apply-colors,
  # wallpaper-picker, ...), shared with the Arch dotfiles repo -- see
  # ./hyprland/bin/. They call their tools by bare name, which the session's
  # PATH (home.packages + environment.systemPackages) provides.
  hyprScripts = map
    (name: pkgs.writeScriptBin name (builtins.readFile (./hyprland/bin + "/${name}")))
    (builtins.attrNames (builtins.readDir ./hyprland/bin));

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

    # --- Hyprland session (./hyprland/) ---
    kitty
    wofi
    waybar
    hyprpaper
    hyprlock
    matugen # wallpaper -> ~/.config/hypr/colors.css, see ./hyprland/matugen/
    swaynotificationcenter # notification daemon, no Wayland/layer-shell support in dunst (Awesome's daemon)
    grim # screenshot capture, see ./hyprland/bin/screenshot-region
    slurp # region selector for screenshot-region
    wl-clipboard # wl-copy/wl-paste, used by screenshot-region and cliphist
    cliphist # clipboard history, see ./hyprland/bin/clipboard-picker

    # Qt apps (hyprpolkitagent, ...) in the Hyprland session take their style,
    # colors and icons from qt6ct (QT_QPA_PLATFORMTHEME, set in hyprland.lua).
    kdePackages.qt6ct
    kdePackages.breeze
  ] ++ hyprScripts;

  home.sessionVariables = {
    EDITOR = "vim";
  };

  # `xsession.enable` is deliberately left off (it would also generate an
  # unconditional ~/.xsession that hijacks every login-screen session choice
  # back into i3 — see the multi-session setup below). But every session's
  # generic launch script still sources ~/.xprofile if present, so recreate
  # just that one piece by hand: without it, home.sessionVariables (EDITOR,
  # QT_QPA_PLATFORMTHEME, etc.) never reach the session's actual
  # process tree, only systemd-managed services like quickshell.
  home.file.".xprofile".text = ''
    . "${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh"
  '';

  # Same theme, icons and font as the Arch setup. matugen layers the
  # wallpaper's colors on top through ~/.config/gtk-{3,4}.0/gtk.css (see
  # ./hyprland/matugen/), so neither file may be managed here: gtk4.theme
  # defaults to gtk.theme, and with it set home-manager writes its own
  # gtk-4.0/gtk.css -- a read-only symlink matugen can't overwrite.
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    gtk4.theme = null;
    # The rest of what nwg-look writes on Arch, for identical settings.ini files.
    gtk3.extraConfig = {
      gtk-button-images = 0;
      gtk-menu-images = 0;
      gtk-enable-event-sounds = 1;
      gtk-enable-input-feedback-sounds = 0;
      gtk-toolbar-style = "GTK_TOOLBAR_ICONS";
      gtk-toolbar-icon-size = "GTK_ICON_SIZE_LARGE_TOOLBAR";
      gtk-xft-antialias = 1;
      gtk-xft-hinting = 1;
      gtk-xft-hintstyle = "hintslight";
      gtk-xft-rgba = "rgb";
    };
    # Name only (no package), so home-manager still leaves gtk-4.0/gtk.css alone.
    gtk4.extraConfig.gtk-theme-name = "adw-gtk3-dark";
    iconTheme = {
      name = "Papirus";
      package = pkgs.papirus-icon-theme;
    };
    font = {
      name = "Adwaita Sans";
      size = 11;
      package = pkgs.adwaita-fonts;
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

  # Login shell (users.users.*.shell in configuration.nix), set up like
  # fish/config.fish in the Arch dotfiles. Completions from man pages are
  # generated by home-manager itself (programs.fish.generateCompletions).
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -g fish_greeting

      fastfetch
      echo
      echo
      echo
    '';
    # rebuild: apply the config in ~/nixos as-is (same pinned versions).
    # upgrade: bump every flake input in flake.lock (nixpkgs, home-manager,
    # zen-browser, ...), rebuild with them, then update Flatpak apps too.
    # nix-flatpak only installs the apps listed in configuration.nix; it
    # doesn't update them on rebuild, hence the explicit flatpak update.
    functions = {
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos#nixos $argv";
      upgrade = ''
        nix flake update --flake ~/nixos
        and rebuild $argv
        and flatpak update -y
      '';
    };
  };

  # Prompt. No settings here on purpose: ~/.config/starship.toml is
  # generated by matugen from the wallpaper (./hyprland/matugen/templates/
  # starship.toml), and home-manager only writes that file when settings
  # are given. enableFishIntegration (on by default) adds the
  # `starship init fish | source` line.
  programs.starship.enable = true;

  programs.git = {
    enable = true;
    settings.user = {
      name = "crosseyedCOBRA";
      email = "crosseyedcobra@gmail.com";
    };
    # Signs commits with the GitHub SSH key (install.sh says how to make it).
    # GitHub only shows them as Verified once the same key is also added there
    # as a *signing* key, not just an authentication one.
    signing = {
      format = "ssh";
      key = "~/.ssh/id_ed25519.pub";
      signByDefault = true;
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

  # Polkit agent for the Hyprland session (started from hyprland.lua's
  # autostart). The Awesome session keeps using polkit-agent above.
  services.hyprpolkitagent.enable = true;

  xdg.enable = true;
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
  # matugen's fastfetch template (./hyprland/matugen/) now owns that file
  # entirely, regenerated on every login/wallpaper change, same as
  # colors.css/kitty's colors.conf.

  # --- Hyprland session ---
  # Shared with the Arch dotfiles repo (github.com/crosseyedCOBRA/hyprland);
  # the NixOS-specific differences are commented where they occur.
  # Hyprland 0.55+ defaults to Lua config (hyprlang/.conf is deprecated).
  xdg.configFile."hypr/hyprland.lua".source = ./hyprland/hyprland.lua;
  xdg.configFile."hypr/hyprpaper.conf".source = ./hyprland/hyprpaper.conf;
  xdg.configFile."hypr/hyprlock.conf".source = ./hyprland/hyprlock.conf;
  xdg.configFile."hypr/pill-border.css".source = ./hyprland/pill-border.css;
  xdg.configFile."waybar/config.jsonc".source = ./hyprland/waybar/config.jsonc;
  xdg.configFile."waybar/shared.jsonc".source = ./hyprland/waybar/shared.jsonc;
  # waybar/swaync's style.css @import colors.css (and waybar also
  # pill-border.css) by a "../hypr/..." relative path -- but these files
  # are deployed as symlinks into the Nix store, and GTK's CSS @import
  # resolves relative paths against that symlink's resolved store
  # location, not ~/.config. colors.css is deliberately NOT part of that
  # static store tree (matugen overwrites it at runtime), so the relative
  # import 404s silently, GTK drops every rule that references an
  # @define-color from it, and the window renders with no background at
  # all. Substituting in an absolute path (still derived from
  # home.homeDirectory, not a hardcoded username) at build time keeps the
  # portability goal while actually resolving correctly. wofi's style.css
  # is generated by matugen itself now (templates/wofi-style.css), so it's
  # a real file and isn't deployed here at all.
  xdg.configFile."waybar/style.css".text = builtins.replaceStrings
    [ "../hypr/colors.css" "../hypr/pill-border.css" ]
    [ "${config.home.homeDirectory}/.config/hypr/colors.css" "${config.home.homeDirectory}/.config/hypr/pill-border.css" ]
    (builtins.readFile ./hyprland/waybar/style.css);
  xdg.configFile."wofi/config".source = ./hyprland/wofi/config;
  # config.toml + the templates are versioned; everything they *generate*
  # (~/.config/hypr/colors.css, kitty/colors.conf, wofi/style.css,
  # gtk-{3,4}.0/gtk.css, ...) deliberately isn't deployed here -- matugen
  # needs to write those at runtime, and a file this deploys would be a
  # read-only store symlink matugen couldn't overwrite.
  xdg.configFile."matugen/config.toml".source = ./hyprland/matugen/config.toml;
  # One link per template, not the folder: earlier generations linked them
  # individually, and home-manager won't replace that real folder with a link.
  xdg.configFile."matugen/templates/btop.theme".source = ./hyprland/matugen/templates/btop.theme;
  xdg.configFile."matugen/templates/colors.css".source = ./hyprland/matugen/templates/colors.css;
  xdg.configFile."matugen/templates/colors.sh".source = ./hyprland/matugen/templates/colors.sh;
  xdg.configFile."matugen/templates/fastfetch.jsonc".source = ./hyprland/matugen/templates/fastfetch.jsonc;
  xdg.configFile."matugen/templates/gtk3.css".source = ./hyprland/matugen/templates/gtk3.css;
  xdg.configFile."matugen/templates/gtk4.css".source = ./hyprland/matugen/templates/gtk4.css;
  xdg.configFile."matugen/templates/hyprlock-colors.conf".source = ./hyprland/matugen/templates/hyprlock-colors.conf;
  xdg.configFile."matugen/templates/kitty-colors.conf".source = ./hyprland/matugen/templates/kitty-colors.conf;
  xdg.configFile."matugen/templates/starship.toml".source = ./hyprland/matugen/templates/starship.toml;
  xdg.configFile."matugen/templates/swayosd.css".source = ./hyprland/matugen/templates/swayosd.css;
  xdg.configFile."matugen/templates/vesktop.theme.css".source = ./hyprland/matugen/templates/vesktop.theme.css;
  xdg.configFile."matugen/templates/wofi-style.css".source = ./hyprland/matugen/templates/wofi-style.css;
  xdg.configFile."kitty/kitty.conf".source = ./hyprland/kitty/kitty.conf;
  xdg.configFile."swaync/config.json".source = ./hyprland/swaync/config.json;
  xdg.configFile."swaync/style.css".text = builtins.replaceStrings
    [ "../hypr/colors.css" ]
    [ "${config.home.homeDirectory}/.config/hypr/colors.css" ]
    (builtins.readFile ./hyprland/swaync/style.css);
  # qt6ct.conf points at its color scheme by absolute path.
  xdg.configFile."qt6ct/qt6ct.conf".text = builtins.replaceStrings
    [ "/home/mike/" ]
    [ "${config.home.homeDirectory}/" ]
    (builtins.readFile ./hyprland/qt6ct/qt6ct.conf);
  xdg.configFile."qt6ct/colors/breeze-dark.conf".source = ./hyprland/qt6ct/colors/breeze-dark.conf;
  # The scripts look for wallpapers in ~/.config/wallpapers -- the same
  # wallpapers/ folder the Arch setup uses, from the hyprland-dotfiles flake
  # input (see flake.nix).
  xdg.configFile."wallpapers".source = "${inputs.hyprland-dotfiles}/wallpapers";

  # Folders matugen renders into but nothing else creates (it won't create
  # them itself), and Vesktop's theme switched on -- Vesktop rewrites its
  # own settings.json, so it's merged into rather than deployed.
  #
  # kdeglobals (KDE apps' colors), btop.conf (color_theme = matugen) and
  # MangoHud.conf (the in-game overlay; MangoJuice edits it) are copied, not
  # linked: those apps rewrite these files themselves,
  # which a read-only store link would break. Like install.sh on Arch, the
  # repo version wins on every switch; the replaced file is kept as .bak.
  home.activation.hyprlandThemeDirs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    place() {
      if [ -e "$2" ] && ! ${pkgs.diffutils}/bin/cmp -s "$1" "$2"; then run cp "$2" "$2.bak"; fi
      ${pkgs.diffutils}/bin/cmp -s "$1" "$2" || run install -Dm644 "$1" "$2"
    }
    place ${./hyprland/kde/kdeglobals} "$HOME/.config/kdeglobals"
    place ${./hyprland/btop/btop.conf} "$HOME/.config/btop/btop.conf"
    place ${./hyprland/mangohud/MangoHud.conf} "$HOME/.config/MangoHud/MangoHud.conf"
    run mkdir -p "$HOME/.cache/hypr" "$HOME/.config/swayosd" "$HOME/.config/btop/themes" \
      "$HOME/.config/vesktop/themes" "$HOME/.config/fastfetch"
    vesk="$HOME/.config/vesktop/settings/settings.json"
    if [ ! -f "$vesk" ]; then
      run install -Dm644 ${pkgs.writeText "vesktop-settings.json" "{ \"enabledThemes\": [\"matugen.theme.css\"] }"} "$vesk"
    elif ! ${pkgs.jq}/bin/jq -e '.enabledThemes // [] | index("matugen.theme.css")' "$vesk" >/dev/null; then
      tmp=$(mktemp)
      ${pkgs.jq}/bin/jq '.enabledThemes = ((.enabledThemes // []) + ["matugen.theme.css"] | unique)' "$vesk" > "$tmp" \
        && run mv "$tmp" "$vesk"
    fi
  '';

  # Firefox/Zen sandbox its cubeb audio backend into the RDD process by
  # default, which is a well-documented source of intermittent audio
  # popping/crackling when the underlying backend is PipeWire (as here --
  # confirmed via `wpctl status`: Zen connects through pipewire-pulse).
  # user.js (unlike prefs.js) is read fresh on every startup and never
  # gets overwritten by the browser itself, so it's the right place for a
  # durable override outside of about:config.
  xdg.configFile."zen/az49i3nb.Default Profile/user.js".text = ''
    user_pref("media.cubeb.sandbox", false);
  '';
}
