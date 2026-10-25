{
  config,
  lib,
  pkgs,
  ...
}:

let
  manifest = lib.importJSON ../../pkgs/linux-cachyos-bc250/manifest.json;
  kernel = config.boot.kernelPackages.kernel;
  runningVersion = lib.versions.majorMinor kernel.version;
in
{
  options.hardware.bc250.driverPatch.enable =
    lib.mkEnableOption ''
      the kernel drivers and Mesa with the BC-250 patch series from
      linux-cachyos-bc250, on the CachyOS kernel the series targets
    ''
    // {
      default = true;
    };

  config = lib.mkMerge [
    (lib.mkIf config.hardware.bc250.driverPatch.enable {
      # The CachyOS kernel the patch series is made for.
      boot.kernelPackages = lib.mkDefault pkgs.bc250-linuxPackages;

      nix.settings = {
        substituters = [ "https://nyx-cache.chaotic.cx/" ];
        trusted-public-keys = [ "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk=" ];
      };

      boot.extraModulePackages = [
        # Built with the plain package set of the kernel's nixpkgs, as the
        # binary cache does not cover the kernel's own build environment.
        (pkgs.bc250-kernelBuildPackages.callPackage ../../pkgs/bc250-kernel-modules {
          inherit (config.boot.kernelPackages) kernel;
          inherit (pkgs) linux-cachyos-bc250-src;
        })
      ];

      # Overrides the default Mesa; an explicit setting still takes
      # precedence. The 32-bit driver remains stock, as the patch series has
      # no effect on 32-bit processes.
      hardware.graphics.package = lib.mkOverride 900 pkgs.bc250-mesa;

      warnings =
        lib.optional (runningVersion != manifest.kernel) ''
          hardware.bc250.driverPatch: the patch series targets Linux ${manifest.kernel}, but the
          kernel is ${runningVersion}. The patched drivers may fail to build or misbehave.
        ''
        ++ lib.optional (!lib.hasSuffix "-cachyos" kernel.modDirVersion) ''
          hardware.bc250.driverPatch: the patch series is made for the CachyOS kernel. On
          another kernel, features that depend on CachyOS changes may be missing.
        '';

      # The patched driver reports GPU load itself and accepts the full
      # clock range, so the governor can set clocks through it.
      services.cyan-skillfish-governor-smu.settings = {
        gpu-usage = {
          method = lib.mkDefault "kernel";
          fix-metrics = lib.mkDefault false;
        };
        gpu.set-method = lib.mkDefault "kernel";
      };
    })

    (lib.mkIf (!config.hardware.bc250.driverPatch.enable) {
      assertions = [
        {
          assertion =
            (config.services.cyan-skillfish-governor-smu.settings.gpu-usage.method or null) != "kernel";
          message = ''
            services.cyan-skillfish-governor-smu: gpu-usage.method = "kernel" needs the
            patched amdgpu driver (hardware.bc250.driverPatch.enable).
          '';
        }
      ];
    })
  ];
}
