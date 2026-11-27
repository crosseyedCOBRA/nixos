{
  description = "Mike's NixOS configuration - i3 + home-manager";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    # My dwl (dwm for Wayland): dwl v0.9 with dwl-patches and my config.h,
    # plus my native HDMI mirroring (modules/dwl.nix builds it). The
    # local repo for now, while it's a prototype: commit in ~/src/dwl, then
    # `nix flake update dwl`. Moves to github:crosseyedCOBRA/dwl once pushed.
    dwl = {
      url = "git+file:///home/mike/src/dwl";
      flake = false;
    };

    # Secure Boot for NixOS (modules/boot.nix), so it keeps booting with
    # Secure Boot on -- which Windows' Vanguard anti-cheat requires.
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v1.2.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # The Arch dotfiles repo, for its wallpapers/ folder (home.nix links it to
    # ~/.config/wallpapers) -- one copy of the images instead of two. After
    # adding wallpapers there: `nix flake update hyprland-dotfiles`.
    hyprland-dotfiles = {
      url = "github:crosseyedCOBRA/hyprland";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }@inputs:
    let
      username = "mike";
      hostname = "nixos";
    in
    {
      nixosConfigurations.${hostname} = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit username inputs; };
        modules = [
          { nixpkgs.hostPlatform = "x86_64-linux"; }
          ./configuration.nix
          inputs.nix-flatpak.nixosModules.nix-flatpak
          inputs.lanzaboote.nixosModules.lanzaboote
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit username inputs; };
            home-manager.users.${username} = import ./home.nix;
          }
        ];
      };
    };
}
