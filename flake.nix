{
  description = "NixOS hardware support for the AMD BC-250";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  # Not following nixpkgs: the CachyOS kernel only comes from the
  # binary cache when built against the nixpkgs this input pins.
  inputs.chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

  outputs =
    {
      self,
      nixpkgs,
      chaotic,
    }:
    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";

      # Packages under an unfree license: the Proton builds include NVIDIA
      # components, and the CH7218 updater and images from UGREEN carry no
      # license. This only allows them in this flake's own outputs; a
      # system using them allows the license in its own configuration.
      unfreePackages = [
        "bc250-ch7218-fw"
        "proton-cachyos-slr-bc250"
        "protonge-latest-bc250"
      ];

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ self.overlays.default ];
        config.allowUnfreePredicate = pkg: lib.elem (lib.getName pkg) unfreePackages;
      };

      kernelPackages = pkgs.bc250-linuxPackages;

      # Packages nix-update can bump, with the version source each follows.
      updatable = {
        bc250-acpi-fix = [ ];
        bc250-cu-live-manager = [ "--version=branch" ];
        bc250-memcfg = [ "--version=branch" ];
        bc250-smu-oc = [ "--version=branch" ];
        bc250-smu-patch = [ "--version=branch" ];
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
      overlays.default = lib.composeExtensions (import ./pkgs) (
        final: prev: {
          bc250-linuxPackages =
            chaotic.legacyPackages.${final.stdenv.hostPlatform.system}.linuxPackages_cachyos;
          # The nixpkgs the CachyOS kernel is built against, for building
          # the patched modules: its plain build environment is cached,
          # unlike the kernel's own.
          bc250-kernelBuildPackages =
            chaotic.inputs.nixpkgs.legacyPackages.${final.stdenv.hostPlatform.system};
        }
      );

      nixosModules.default = {
        imports = [ ./modules ];
        nixpkgs.overlays = [ self.overlays.default ];
      };

      packages.${system} = {
        inherit (pkgs)
          bc250-acpi-fix
          bc250-ch7218-fw
          bc250-core-unlock
          bc250-cu-live-manager
          bc250-memcfg
          bc250-mesa
          bc250-smu-oc
          bc250-smu-patch
          cyan-skillfish-governor-smu
          linux-cachyos-bc250-src
          proton-cachyos-slr-bc250
          protonge-latest-bc250
          ;
        bc250-kernel-modules = pkgs.bc250-kernelBuildPackages.callPackage ./pkgs/bc250-kernel-modules {
          inherit (kernelPackages) kernel;
          inherit (pkgs) linux-cachyos-bc250-src;
        };
      };

      checks.${system} = removeAttrs self.packages.${system} unfreePackages // {
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
        # nixos-generate-config's output when it finds no swap.
        eval-generated-swap = evalCheck "generated-swap" { swapDevices = [ ]; };
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
              mismatch=
              ${lib.concatStrings (
                lib.mapAttrsToList (attr: flags: ''
                  nix-update --flake ${lib.escapeShellArgs flags} ${attr} || failed+=(${attr})
                '') updatable
              )}
              status=0
              ${lib.getExe (pkgs.callPackage ./pkgs/linux-cachyos-bc250/update.nix { })} \
                pkgs/linux-cachyos-bc250/manifest.json || status=$?
              case "$status" in
                0) ;;
                10) mismatch=1 ;;
                *) failed+=(linux-cachyos-bc250) ;;
              esac

              if [ "''${#failed[@]}" -gt 0 ]; then
                echo "failed to update: ''${failed[*]}" >&2
                exit 1
              fi
              # Exit status 10: only the kernel branches differ.
              [ -z "$mismatch" ] || exit 10
            '';
          }
        );
      };

      formatter.${system} = pkgs.nixfmt-tree;
    };
}
