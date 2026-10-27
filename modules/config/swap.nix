{
  config,
  lib,
  ...
}:

{
  options.hardware.bc250.swapFile.enable =
    lib.mkEnableOption "the 16 GB swap file zswap uses as its backing store"
    // {
      default = true;
    };

  config = lib.mkMerge [
    {
      boot.zswap = {
        enable = lib.mkDefault true;
        compressor = lib.mkDefault "lz4";
      };

      boot.kernel.sysctl."vm.swappiness" = lib.mkDefault 180;

      assertions = [
        {
          assertion = !config.zramSwap.enable;
          message = ''
            zram swap crashes memory-hungry games on the BC-250 when the GPU takes
            memory on demand. Use zswap with disk swap, which this configuration
            sets up by default.
          '';
        }
      ];
    }

    (lib.mkIf config.hardware.bc250.swapFile.enable {
      # nixos-generate-config writes an empty swap list when it finds no
      # swap, which must not replace the file.
      swapDevices = lib.mkAfter [
        {
          device = "/var/lib/swapfile";
          size = 16384;
        }
      ];
    })
  ];
}
