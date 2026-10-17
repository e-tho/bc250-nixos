{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.bc250.vram;
  memcfg = lib.getExe pkgs.bc250-memcfg;

  applySplit = pkgs.writeShellScript "bc250-vram-split" ''
    set -eu
    current=$(${memcfg} | ${pkgs.gnused}/bin/sed -n 's/^UMA_SIZE=//p')
    if [ -n "$current" ] && [ "$((10#$current))" -eq ${toString cfg.split} ]; then
      echo "UMA_SIZE is already ${toString cfg.split} MB"
    else
      ${memcfg} UMA_SIZE ${toString cfg.split}
    fi
  '';
in
{
  options.hardware.bc250.vram = {
    split = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 6144;
      description = ''
        Memory reserved for the GPU, in MB, taken from system RAM. The display
        can only use this memory, so small values can crash the session when a
        game fills it. Written to CMOS with bc250memcfg when it differs.
        Unsetting it leaves CMOS as it is; the stock BIOS reserves 8192.
      '';
    };

    dynamicLimit = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 4096;
      description = ''
        System RAM the GPU may take on demand, in MB, on top of `split`.
        Sets `ttm.pages_limit`; when unset, the kernel allows half of the
        system RAM left after `split`.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf (cfg.split != null) {
      assertions = [
        {
          assertion = cfg.split != 2048;
          message = "hardware.bc250.vram.split = 2048 prevents the graphics driver from starting; pick another size.";
        }
      ];

      system.activationScripts.bc250-vram-split.text = ''
        ${applySplit} || echo "bc250: could not write the VRAM split to CMOS" >&2
      '';

      systemd.services.bc250-vram-split = {
        description = "Apply the BC-250 VRAM split";
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = applySplit;
        };
      };
    })

    (lib.mkIf (cfg.dynamicLimit != null) {
      # The GPU memory limit counts 4 KiB pages.
      boot.kernelParams = [ "ttm.pages_limit=${toString (cfg.dynamicLimit * 256)}" ];
    })
  ];
}
