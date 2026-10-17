{
  config,
  lib,
  ...
}:

{
  boot.zswap = {
    enable = lib.mkDefault true;
    compressor = lib.mkDefault "lz4";
  };

  boot.kernel.sysctl."vm.swappiness" = lib.mkDefault 180;

  swapDevices = lib.mkDefault [
    {
      device = "/var/lib/swapfile";
      size = 16384;
    }
  ];

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
