# The desktop pieces dwl uses, from the Awesome days (hence the name): the
# quickshell bar, rofi, alacritty, the power menu and the wallpaper/colors
# scripts. Colors follow the wallpaper: ../awesome/bin/awesome-colors
# renders them with matugen (../awesome/matugen/) into files each of these
# reads. Imported first in ../home.nix so its part of home.packages keeps
# its place at the front of the combined list.
{ config, lib, pkgs, inputs, ... }:

let
  # Fallback wallpaper, before the first random pick (and for its colors,
  # see home.activation.awesomeColors).
  wallpaper = ../assets/wallpaper.jpg;

  # ../awesome/bin/ (awesome-colors, awesome-wallpaper-picker), packaged like
  # Hyprland's ../hyprland/bin/ (see ./hyprland.nix): tools by bare name,
  # from the session's PATH.
  awesomeScripts = map
    (name: pkgs.writeScriptBin name (builtins.readFile (../awesome/bin + "/${name}")))
    (builtins.attrNames (builtins.readDir ../awesome/bin));
in
{
  home.packages = with pkgs; [
    inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default
    libnotify
    playerctl
    brightnessctl
    pavucontrol
    thunar
    tumbler # Thunar delegates all thumbnailing (image previews, etc.) to this D-Bus service -- no previews without it
    imagemagick # awesome-wallpaper-picker's thumbnails

    (writeShellScriptBin "power-menu" ''
      choice=$(printf 'Lock\nLogout\nSuspend\nReboot\nShutdown' | \
        ${rofi}/bin/rofi -dmenu -p "Power" -theme-str 'listview { lines: 5; }')
      case "$choice" in
        Lock) dwl-lock ;;
        Logout) ${systemd}/bin/loginctl terminate-session "$XDG_SESSION_ID" ;;
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

  # The matugen config and templates awesome-colors renders.
  xdg.configFile."matugen/awesome.toml".source = ../awesome/matugen/config.toml;
  xdg.configFile."matugen/awesome/templates".source = ../awesome/matugen/templates;
  # The app templates (GTK, starship, fastfetch, btop, Vesktop), shared with
  # Hyprland's color config.
  xdg.configFile."matugen/awesome/apps/gtk3.css".source = ../hyprland/matugen/templates/gtk3.css;
  # swaync's colors (it @imports ~/.config/hypr/colors.css), for dwl
  xdg.configFile."matugen/awesome/apps/colors.css".source = ../hyprland/matugen/templates/colors.css;
  # hyprlock's colors (dwl's lock screen, see dwl-lock in ./dwl.nix)
  xdg.configFile."matugen/awesome/apps/hyprlock-colors.conf".source = ../hyprland/matugen/templates/hyprlock-colors.conf;
  xdg.configFile."matugen/awesome/apps/gtk4.css".source = ../hyprland/matugen/templates/gtk4.css;
  xdg.configFile."matugen/awesome/apps/starship.toml".source = ../hyprland/matugen/templates/starship.toml;
  xdg.configFile."matugen/awesome/apps/fastfetch.jsonc".source = ../hyprland/matugen/templates/fastfetch.jsonc;
  xdg.configFile."matugen/awesome/apps/btop.theme".source = ../hyprland/matugen/templates/btop.theme;
  xdg.configFile."matugen/awesome/apps/vesktop.theme.css".source = ../hyprland/matugen/templates/vesktop.theme.css;

  # Colors for the fallback wallpaper, so rofi (which @imports its colors
  # file and errors without it) and the rest have some before the first
  # awesome-colors run. Never overwrites colors from a real run.
  home.activation.awesomeColors = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    if [ ! -e "$HOME/.cache/awesome/rofi-colors.rasi" ]; then
      run ${pkgs.matugen}/bin/matugen image -q -m dark --source-color-index 0 \
        -c "$HOME/.config/matugen/awesome.toml" ${wallpaper} </dev/null
    fi
  '';

  xdg.cacheFile."awesome/.keep".text = "";

  # The bar. A systemd unit, so `home-manager switch` restarts it whenever
  # shell.qml or quickshell changes, without logging out. dwl's session
  # starts and stops it (./dwl.nix).
  systemd.user.services.quickshell = {
    Unit = {
      Description = "Quickshell status bar";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${inputs.quickshell.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/quickshell -p %h/.config/quickshell-awesome/shell.qml";
      Restart = "on-failure";
    };
  };

  xdg.configFile."quickshell-awesome/shell.qml".source = ../quickshell/shell.qml;
  xdg.configFile."quickshell-awesome/nix-snowflake-white.svg".source = ../assets/nix-snowflake-white.svg;
  xdg.configFile."quickshell-awesome/awesome-view-tag.sh" = {
    source = ../awesome/view-tag.sh;
    executable = true;
  };
}
