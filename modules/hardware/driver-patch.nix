{
  config,
  lib,
  pkgs,
  ...
}:

let
  manifest = lib.importJSON ../../pkgs/linux-cachyos-bc250/manifest.json;
  kernelAttr = "linuxPackages_${manifest.kernel}";
  targetVersion = lib.replaceStrings [ "_" ] [ "." ] manifest.kernel;
  runningVersion = lib.versions.majorMinor config.boot.kernelPackages.kernel.version;
in
{
  options.hardware.bc250.driverPatch.enable = lib.mkEnableOption ''
    the kernel drivers and Mesa with the BC-250 patch series from
    linux-cachyos-bc250, for its fixes and optimizations, on the kernel
    version the series targets
  '' // { default = true; };

  config = lib.mkMerge [
    (lib.mkIf config.hardware.bc250.driverPatch.enable {
      boot.kernelPackages = lib.mkDefault (
        pkgs.${kernelAttr}
          or (throw "hardware.bc250.driverPatch: nixpkgs has no ${kernelAttr}, which the patch series targets")
      );

      boot.extraModulePackages = [
        (config.boot.kernelPackages.callPackage ../../pkgs/bc250-kernel-modules { })
      ];

      # Replaces the Mesa nixpkgs picks by default; a value set directly in a
      # configuration still takes precedence.
      hardware.graphics.package = lib.mkOverride 900 pkgs.bc250-mesa;
      hardware.graphics.package32 = lib.mkOverride 900 pkgs.pkgsi686Linux.bc250-mesa;

      warnings = lib.optional (runningVersion != targetVersion) ''
        hardware.bc250.driverPatch: the patch series targets Linux ${targetVersion}, but the
        kernel is ${runningVersion}. The patches may not apply.
      '';
      # The patched driver reports GPU load itself.
      services.cyan-skillfish-governor-smu.settings.gpu-usage = {
        method = lib.mkDefault "kernel";
        fix-metrics = lib.mkDefault false;
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
