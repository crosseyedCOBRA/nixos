{ config, pkgs, username, inputs, ... }:

let
  modifier = "Mod4";
  terminal = "alacritty";
  wallpaper = ./assets/wallpaper.jpg;

  # Fixed path (rather than i3's default random tmp path) so quickshell,
  # running as an independent systemd unit, can always connect to it.
  i3SocketPath = "/home/${username}/.cache/i3/ipc-socket";

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
    autotiling
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
        size = 11;
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
    fade = true;
    fadeDelta = 5;
    shadow = true;
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

  xsession.windowManager.i3 = {
    enable = true;
    config = {
      inherit modifier terminal;
      menu = "rofi -show drun -show-icons";

      bars = [ ]; # quickshell owns the bar/panel instead of i3bar

      gaps = {
        inner = 12;
        outer = 4;
      };

      window = {
        border = 2;
        titlebar = false;
        hideEdgeBorders = "none";
      };

      floating = {
        border = 2;
        titlebar = false;
      };

      colors = {
        background = colors.bg;
        focused = {
          border = colors.blue;
          background = colors.blue;
          text = colors.bg;
          indicator = colors.orange;
          childBorder = colors.blue;
        };
        focusedInactive = {
          border = colors.border;
          background = colors.surface;
          text = colors.muted;
          indicator = colors.border;
          childBorder = colors.border;
        };
        unfocused = {
          border = colors.bgAlt;
          background = colors.bg;
          text = colors.muted;
          indicator = colors.bgAlt;
          childBorder = colors.bgAlt;
        };
        urgent = {
          border = colors.pink;
          background = colors.pink;
          text = colors.bg;
          indicator = colors.pink;
          childBorder = colors.pink;
        };
        placeholder = {
          border = colors.bg;
          background = colors.bg;
          text = colors.text;
          indicator = colors.bg;
          childBorder = colors.bg;
        };
      };

      keybindings = let
        mod = modifier;
      in {
        "${mod}+Return" = "exec ${terminal}";
        "${mod}+space" = "exec rofi -show drun -show-icons";
        "${mod}+q" = "kill";
        "${mod}+Shift+c" = "reload";
        "${mod}+Shift+r" = "restart";
        "${mod}+Shift+e" = ''exec i3-nagbar -t warning -m 'Exit i3?' -B 'Yes' 'i3-msg exit' '';

        "${mod}+Left" = "focus left";
        "${mod}+Down" = "focus down";
        "${mod}+Up" = "focus up";
        "${mod}+Right" = "focus right";

        "${mod}+Shift+h" = "move left";
        "${mod}+Shift+j" = "move down";
        "${mod}+Shift+k" = "move up";
        "${mod}+Shift+l" = "move right";

        "${mod}+v" = "split h";
        "${mod}+b" = "split v";
        "${mod}+f" = "fullscreen toggle";
        "${mod}+s" = "layout stacking";
        "${mod}+w" = "layout tabbed";
        "${mod}+t" = "layout toggle split";
        "${mod}+Shift+space" = "floating toggle";
        "${mod}+Tab" = "focus mode_toggle";
        "${mod}+a" = "focus parent";
        "${mod}+e" = "exec thunar";
        "${mod}+d" = "exec toggle-hdmi";

        "${mod}+1" = "workspace number 1";
        "${mod}+2" = "workspace number 2";
        "${mod}+3" = "workspace number 3";
        "${mod}+4" = "workspace number 4";
        "${mod}+5" = "workspace number 5";
        "${mod}+6" = "workspace number 6";
        "${mod}+7" = "workspace number 7";
        "${mod}+8" = "workspace number 8";
        "${mod}+9" = "workspace number 9";
        "${mod}+0" = "workspace number 10";

        "${mod}+Shift+1" = "move container to workspace number 1";
        "${mod}+Shift+2" = "move container to workspace number 2";
        "${mod}+Shift+3" = "move container to workspace number 3";
        "${mod}+Shift+4" = "move container to workspace number 4";
        "${mod}+Shift+5" = "move container to workspace number 5";
        "${mod}+Shift+6" = "move container to workspace number 6";
        "${mod}+Shift+7" = "move container to workspace number 7";
        "${mod}+Shift+8" = "move container to workspace number 8";
        "${mod}+Shift+9" = "move container to workspace number 9";
        "${mod}+Shift+0" = "move container to workspace number 10";

        "${mod}+r" = "mode resize";

        "Print" = "exec flameshot gui";
        "${mod}+Shift+x" = "exec i3lock";

        "XF86AudioRaiseVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ +5%";
        "XF86AudioLowerVolume" = "exec pactl set-sink-volume @DEFAULT_SINK@ -5%";
        "XF86AudioMute" = "exec pactl set-sink-mute @DEFAULT_SINK@ toggle";
        "XF86MonBrightnessUp" = "exec brightnessctl set +5%";
        "XF86MonBrightnessDown" = "exec brightnessctl set 5%-";
        "XF86AudioPlay" = "exec playerctl play-pause";
        "XF86AudioNext" = "exec playerctl next";
        "XF86AudioPrev" = "exec playerctl previous";
      };

      modes = {
        resize = {
          "h" = "resize shrink width 10 px or 10 ppt";
          "j" = "resize grow height 10 px or 10 ppt";
          "k" = "resize shrink height 10 px or 10 ppt";
          "l" = "resize grow width 10 px or 10 ppt";
          "Escape" = "mode default";
          "Return" = "mode default";
        };
      };
    };

    extraConfig = ''
      smart_gaps off

      # Fixed IPC socket path so quickshell (started independently as a
      # systemd unit, not as an i3 child) can always find it.
      ipc-socket ${i3SocketPath}

      # Pin workspaces to monitors. Extra workspaces default to the primary.
      workspace 1 output DisplayPort-0
      workspace 2 output DisplayPort-1
      workspace 3 output DisplayPort-2
      workspace 4 output DisplayPort-0
      workspace 5 output DisplayPort-0
      workspace 6 output DisplayPort-0
      workspace 7 output DisplayPort-0
      workspace 8 output DisplayPort-0
      workspace 9 output DisplayPort-0
      workspace 10 output DisplayPort-0

      # Re-applied here (in addition to the system-level setupCommands in
      # configuration.nix) because at greeter/X-startup time the DisplayPort
      # outputs haven't always finished link-training their custom
      # high-refresh modes yet, which silently fails setupCommands. By the
      # time i3 starts, the outputs are reliably settled.
      # HDMI-A-0 (mirrors DisplayPort-0) stays off by default — mirroring
      # it had a real performance cost — and is toggled on/off via Mod+d
      # (the `toggle-hdmi` script).
      exec_always --no-startup-id ${pkgs.xrandr}/bin/xrandr \
        --output DisplayPort-0 --mode 1920x1080 --rate 165 --pos 0x0 --rotate normal --primary \
        --output DisplayPort-1 --mode 1920x1080 --rate 144 --rotate right --right-of DisplayPort-0 \
        --output DisplayPort-2 --mode 1920x1080 --rate 144 --rotate normal --right-of DisplayPort-1 \
        --output HDMI-A-0 --off

      exec_always --no-startup-id ${pkgs.feh}/bin/feh --bg-fill ${wallpaper}
      exec --no-startup-id polkit-agent
      # Restart quickshell and autotiling once i3 itself is actually up (see
      # the systemd services below for why these are supervised rather than
      # plain `exec` — a plain `exec` never recovers if the process ever
      # dies mid-session, which is what happened to autotiling before).
      exec_always --no-startup-id systemctl --user restart quickshell.service
      exec_always --no-startup-id systemctl --user restart autotiling.service
    '';
  };

  # Ensure ~/.cache/i3 exists before i3 tries to create its socket in it.
  xdg.cacheFile."i3/.keep".text = "";
  xdg.cacheFile."awesome/.keep".text = "";

  # Managed as a systemd unit (rather than i3's `exec`) so that
  # `home-manager switch` restarts it automatically whenever shell.qml
  # or the quickshell package changes, without needing to log out.
  #
  # Deliberately NOT `WantedBy = [ "graphical-session.target" ]`: that
  # target is reached for every session (i3, xfce, awesome, xfce+awesome
  # alike), and quickshell is i3-specific (its bar assumes i3's IPC for
  # workspaces) — it would otherwise auto-start and visually sit on top of
  # Awesome's/XFCE's own bar in the other sessions. i3's own `exec_always`
  # above is what starts/restarts it, so it only ever runs alongside i3.
  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell status bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      Environment = "I3SOCK=${i3SocketPath}";
      ExecStart = "${inputs.quickshell.packages.${pkgs.system}.default}/bin/quickshell -p %h/.config/quickshell/shell.qml";
      Restart = "on-failure";
    };
  };

  # Same reasoning as quickshell above: supervised so it auto-restarts if it
  # ever dies mid-session, instead of silently staying dead until a full i3
  # restart. i3-only (not WantedBy graphical-session.target) since it's
  # triggered by i3's own exec_always, matching quickshell's scoping.
  systemd.user.services.autotiling = {
    Unit = {
      Description = "Automatic BSP/dwindle-style tiling for i3";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.autotiling}/bin/autotiling";
      Restart = "on-failure";
    };
  };

  xdg.enable = true;
  xdg.configFile."quickshell/shell.qml".source = ./quickshell/shell.qml;
  xdg.configFile."awesome/rc.lua".source = ./awesome/rc.lua;
  xdg.configFile."awesome/theme.lua".source = ./awesome/theme.lua;
  xdg.configFile."awesome/wallpaper.jpg".source = wallpaper;
  xdg.configFile."quickshell/awesome-view-tag.sh" = {
    source = ./awesome/view-tag.sh;
    executable = true;
  };

  # Set the same wallpaper in the XFCE-managed sessions ("xfce" and
  # "xfce+awesome"), which don't run our i3 config's feh exec line.
  # xfce4-session scans and runs XDG autostart entries regardless of which
  # window manager it's paired with.
  xdg.configFile."autostart/set-wallpaper.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Set Wallpaper
    Exec=${pkgs.feh}/bin/feh --bg-fill ${wallpaper}
    OnlyShowIn=XFCE;
    X-GNOME-Autostart-enabled=true
  '';

  # Pre-seed XFCE's xsettings daemon with our dark theme/cursor so it
  # doesn't override GTK's settings.ini with its own (light) defaults the
  # first time xfsettingsd runs, in both the plain "xfce" and hybrid
  # "xfce+awesome" sessions.
  xfconf.settings = {
    xsettings = {
      "Net/ThemeName" = "Adwaita-dark";
      "Net/IconThemeName" = "Adwaita";
      "Gtk/CursorThemeName" = "Bibata-Modern-Ice";
      "Gtk/CursorThemeSize" = 24;
    };
  };
}
