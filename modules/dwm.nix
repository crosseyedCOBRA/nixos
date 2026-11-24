# dwm (my fork of dwm-flexipatch, the `dwm` flake input): built with
# nixpkgs' dwm recipe from that source, and offered as a "dwm" session.
# Its startup script and helper scripts are in ../home/dwm.nix.
{ pkgs, inputs, ... }:

let
  dwm = (pkgs.dwm.override {
    extraLibs = [
      pkgs.libxcb # xcb-res, for the swallow patch
      pkgs.yajl # JSON, for the IPC patch (dwm-msg; the quickshell bar uses it)
    ];
  }).overrideAttrs (old: {
    src = inputs.dwm;
    # nixpkgs' postPatch copies its own config.def.h over; the fork's
    # config.h (with patches.h) is the config.
    postPatch = "";
  });
in
{
  environment.systemPackages = [ dwm ];

  # Through NixOS's X session setup like Awesome. Colors first: dwm reads
  # them from Xresources (xresources patch) only when it starts, so the
  # wallpaper is picked and its colors merged before dwm runs. Later
  # wallpaper changes restart dwm in place (restartsig) to recolor it.
  services.xserver.windowManager.session = [{
    name = "dwm";
    start = ''
      awesome-colors --random-once
      [ -e "$HOME/.cache/awesome/dwm.Xresources" ] && xrdb -merge "$HOME/.cache/awesome/dwm.Xresources"
      ${dwm}/bin/dwm &
      waitPID=$!
    '';
  }];
}
