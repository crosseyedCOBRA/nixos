# ZarisWM (github.com/crosseyedCOBRA/zaris), my own X11 tiling window
# manager: built from the `zaris` flake input, with the tools its shell
# calls, and a "ZarisWM" session in the login screen. The shell's configs
# are set up per user by ../home/zaris.nix.
{ pkgs, inputs, ... }:

let
  # No CMake install target upstream (the binary is build/zaris), so
  # installPhase copies it.
  zaris = pkgs.stdenv.mkDerivation {
    pname = "zaris";
    version = "0-unstable";
    src = inputs.zaris;

    # CMakeLists.txt pins CMAKE_CXX_COMPILER to /bin/g++ (inherited from
    # Hypr), which doesn't exist here; let CMake use the build's compiler.
    postPatch = ''
      sed -i '/set(CMAKE_CXX_COMPILER/d' CMakeLists.txt
    '';

    nativeBuildInputs = with pkgs; [ cmake pkg-config ];
    buildInputs = with pkgs; [
      glib
      libxcb
      libxcb-util
      libxcb-wm
      libxcb-keysyms
      libxcb-cursor
    ];

    installPhase = ''
      runHook preInstall
      install -Dm755 zaris $out/bin/zaris
      runHook postInstall
    '';
  };
in
{
  environment.systemPackages = [ zaris ] ++ (with pkgs; [
    # What the shell and zaris.conf call (DEPENDENCIES.md in the zaris repo);
    # quickshell, picom, dunst, rofi, i3lock, xrandr and wireplumber are
    # already installed for the Awesome session.
    wmctrl # workspaces bar module
    maim # screenshots
    xclip
    xss-lock # idle lock timer
    xwallpaper
    redshift # night light toggle
    clipnotify # clipboard history
    xcolor # color picker module
    ddcutil # external monitor brightness
    xrdb # cursor theme sync in start-zaris.sh
    xsetroot
  ]);

  # The shell's battery module talks to upowerd.
  services.upower.enable = true;

  # Run through NixOS's X session setup like Awesome (DISPLAY for user
  # services, ~/.xprofile). start-zaris.sh sets the monitor layout and then
  # execs zaris; it lives in ~/.config/zaris (see ../home/zaris.nix).
  services.xserver.windowManager.session = [{
    name = "zaris";
    start = ''
      ${pkgs.bash}/bin/bash "$HOME/.config/zaris/start-zaris.sh" &
      waitPID=$!
    '';
  }];
}
