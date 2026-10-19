{
  description = "NixOS hardware support for the AMD BC-250";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";

      # The Proton builds include NVIDIA components under an unfree
      # license. This only allows them in this flake's own outputs; a
      # system using them allows the license in its own configuration.
      unfreeTools = [
        "proton-cachyos-slr-bc250"
        "protonge-latest-bc250"
      ];

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
        config.allowUnfreePredicate = pkg: lib.elem (lib.getName pkg) unfreeTools;
      };

      manifest = lib.importJSON ./pkgs/linux-cachyos-bc250/manifest.json;
      kernelPackages = pkgs."linuxPackages_${manifest.kernel}";

      # Packages nix-update can bump, with the version source each follows.
      updatable = {
        bc250-acpi-fix = [ ];
        bc250-cu-live-manager = [ "--version=branch" ];
        bc250-memcfg = [ "--version=branch" ];
        bc250-smu-oc = [ "--version=branch" ];
        bc250-smu-unlock = [ "--version=branch" ];
        cyan-skillfish-governor-smu = [ "--version=branch=smu" ];
      };

      evalSystem =
        extra:
        (lib.nixosSystem {
          modules = [
            self.nixosModules.default
            {
              nixpkgs.hostPlatform = system;
              fileSystems."/" = {
                device = "/dev/disk/by-label/nixos";
                fsType = "ext4";
              };
              boot.loader.grub.enable = false;
              system.stateVersion = "26.05";
            }
            extra
          ];
        }).config.system.build.toplevel;

      evalCheck =
        name: extra:
        pkgs.writeText "eval-${name}" (builtins.unsafeDiscardStringContext (evalSystem extra).drvPath);
    in
    {
      overlays.default = import ./pkgs;

      nixosModules.default = ./modules;

      packages.${system} = {
        inherit (pkgs)
          bc250-acpi-fix
          bc250-core-unlock
          bc250-cu-live-manager
          bc250-memcfg
          bc250-mesa
          bc250-smu-oc
          bc250-smu-unlock
          cyan-skillfish-governor-smu
          linux-cachyos-bc250-src
          proton-cachyos-slr-bc250
          protonge-latest-bc250
          ;
        bc250-kernel-modules = kernelPackages.callPackage ./pkgs/bc250-kernel-modules { };
        bc250-mesa-32 = pkgs.pkgsi686Linux.bc250-mesa;
      };

      checks.${system} = removeAttrs self.packages.${system} unfreeTools // {
        eval-default = evalCheck "default" { };
        eval-unlocked = evalCheck "unlocked" {
          hardware.bc250.coreUnlock.enable = true;
          hardware.bc250.cuUnlock.enable = true;
          hardware.bc250.vram.split = 6144;
        };
        eval-stock-drivers = evalCheck "stock-drivers" {
          hardware.bc250.driverPatch.enable = false;
          hardware.bc250.coreUnlock.enable = true;
        };
      };

      # Updates versions and hashes in place, without committing. Expects to
      # run from the project root.
      apps.${system}.update = {
        type = "app";
        meta.description = "Update every package to its latest upstream version";
        program = lib.getExe (
          pkgs.writeShellApplication {
            name = "update";
            runtimeInputs = [ pkgs.nix-update ];
            text = ''
              failed=()
              ${lib.concatStrings (
                lib.mapAttrsToList (attr: flags: ''
                  nix-update --flake ${lib.escapeShellArgs flags} ${attr} || failed+=(${attr})
                '') updatable
              )}
              ${lib.getExe (pkgs.callPackage ./pkgs/linux-cachyos-bc250/update.nix { })} \
                pkgs/linux-cachyos-bc250/manifest.json || failed+=(linux-cachyos-bc250)

              if [ "''${#failed[@]}" -gt 0 ]; then
                echo "failed to update: ''${failed[*]}" >&2
                exit 1
              fi
            '';
          }
        );
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
