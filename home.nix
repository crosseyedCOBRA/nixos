{ config, pkgs, username, inputs, ... }:

let
  modifier = "Mod4";
  terminal = "alacritty";
  wallpaper = ./assets/wallpaper.jpg;
in
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.11";

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
    networkmanagerapplet
    thunar
  ];

  home.sessionVariables = {
    EDITOR = "vim";
  };

  home.pointerCursor = {
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  programs.home-manager.enable = true;

  programs.git = {
    enable = true;
    userName = "crosseyedCOBRA";
    userEmail = "crosseyedcobra@gmail.com";
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

      keybindings = let
        mod = modifier;
      in {
        "${mod}+Return" = "exec ${terminal}";
        "${mod}+space" = "exec rofi -show drun -show-icons";
        "${mod}+q" = "kill";
        "${mod}+Shift+c" = "reload";
        "${mod}+Shift+r" = "restart";
        "${mod}+Shift+e" = ''exec i3-nagbar -t warning -m 'Exit i3?' -B 'Yes' 'i3-msg exit' '';

        "${mod}+h" = "focus left";
        "${mod}+j" = "focus down";
        "${mod}+k" = "focus up";
        "${mod}+l" = "focus right";

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
      exec_always --no-startup-id ${pkgs.feh}/bin/feh --bg-fill ${wallpaper}
      exec --no-startup-id quickshell
      exec --no-startup-id nm-applet
    '';
  };

  xdg.enable = true;
  xdg.configFile."quickshell/shell.qml".source = ./quickshell/shell.qml;
}
