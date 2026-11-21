# GTK, Qt and cursor theme (matugen recolors GTK on top, see ./hyprland.nix).
{ lib, pkgs, ... }:

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

  home.pointerCursor = {
    enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 24;
    gtk.enable = true;
    x11.enable = true;
  };
}
