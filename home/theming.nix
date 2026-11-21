# GTK, Qt and cursor theme, wallpapers, and app configs shared by sessions
# (matugen recolors GTK and apps on top, see ../awesome/bin/awesome-colors).
{ config, lib, pkgs, inputs, ... }:

{
  # Same theme, icons and font as the Arch setup. matugen layers the
  # wallpaper's colors on top through ~/.config/gtk-{3,4}.0/gtk.css (see
  # ../hyprland/matugen/), so neither file may be managed here: gtk4.theme
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

  # Qt apps (OpenRGB, flameshot, ...) take their style, colors and icons
  # from qt6ct -- Breeze, dark palette, Papirus-Dark, configured in
  # ~/.config/qt6ct/qt6ct.conf (../hyprland/qt6ct/) -- in every session, so
  # they look the same in Awesome as in Hyprland. home-manager's "qtct"
  # names the qt5ct plugin, so the variable is pinned to qt6ct's own name.
  # No style override: it would replace qt6ct's Breeze.
  qt = {
    enable = true;
    platformTheme.name = "qtct";
  };
  home.sessionVariables.QT_QPA_PLATFORMTHEME = lib.mkForce "qt6ct";

  home.packages = with pkgs; [
    kdePackages.qt6ct
    kdePackages.breeze # the Qt style qt6ct.conf picks
    matugen # wallpaper colors, see ../awesome/bin/awesome-colors
  ];

  # qt6ct.conf points at its color scheme by absolute path.
  xdg.configFile."qt6ct/qt6ct.conf".text = builtins.replaceStrings
    [ "/home/mike/" ]
    [ "${config.home.homeDirectory}/" ]
    (builtins.readFile ../hyprland/qt6ct/qt6ct.conf);
  xdg.configFile."qt6ct/colors/breeze-dark.conf".source = ../hyprland/qt6ct/colors/breeze-dark.conf;

  # Wallpapers live in ~/.config/wallpapers -- the wallpapers/ folder of the
  # Arch dotfiles repo, from the hyprland-dotfiles flake input (flake.nix).
  xdg.configFile."wallpapers".source = "${inputs.hyprland-dotfiles}/wallpapers";

  # Vesktop's matugen theme switched on (Vesktop rewrites its own
  # settings.json, so it's merged into rather than deployed), and the
  # folders matugen renders app colors into (it won't create them).
  #
  # kdeglobals (KDE apps' colors), btop.conf (color_theme = matugen) and
  # MangoHud.conf (the in-game overlay; MangoJuice edits it) are copied, not
  # linked: those apps rewrite these files themselves, which a read-only
  # store link would break. The repo version wins on every switch; the
  # replaced file is kept as .bak.
  home.activation.appConfigs = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    place() {
      if [ -e "$2" ] && ! ${pkgs.diffutils}/bin/cmp -s "$1" "$2"; then run cp "$2" "$2.bak"; fi
      ${pkgs.diffutils}/bin/cmp -s "$1" "$2" || run install -Dm644 "$1" "$2"
    }
    place ${../hyprland/kde/kdeglobals} "$HOME/.config/kdeglobals"
    place ${../hyprland/btop/btop.conf} "$HOME/.config/btop/btop.conf"
    place ${../hyprland/mangohud/MangoHud.conf} "$HOME/.config/MangoHud/MangoHud.conf"
    run mkdir -p "$HOME/.config/btop/themes" "$HOME/.config/vesktop/themes" "$HOME/.config/fastfetch"
    vesk="$HOME/.config/vesktop/settings/settings.json"
    if [ ! -f "$vesk" ]; then
      run install -Dm644 ${pkgs.writeText "vesktop-settings.json" "{ \"enabledThemes\": [\"matugen.theme.css\"] }"} "$vesk"
    elif ! ${pkgs.jq}/bin/jq -e '.enabledThemes // [] | index("matugen.theme.css")' "$vesk" >/dev/null; then
      tmp=$(mktemp)
      ${pkgs.jq}/bin/jq '.enabledThemes = ((.enabledThemes // []) + ["matugen.theme.css"] | unique)' "$vesk" > "$tmp" \
        && run mv "$tmp" "$vesk"
    fi
  '';

  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };
}
