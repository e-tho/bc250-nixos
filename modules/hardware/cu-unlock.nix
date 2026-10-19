{
  config,
  lib,
  ...
}:

let
  cfg = config.hardware.bc250.cuUnlock;

  # A pair's first unit; turning it off also turns off its partner.
  toUnit =
    pair:
    let
      parts = map lib.toInt (lib.splitString "." pair);
    in
    "${toString (lib.elemAt parts 0)}.${toString (lib.elemAt parts 1)}.${
      toString (2 * lib.elemAt parts 2)
    }";
in
{
  options.hardware.bc250.cuUnlock = {
    enable = lib.mkEnableOption ''
      unlocking the 16 factory-disabled GPU compute units, through the
      patched amdgpu driver. Stress-test them before use, and keep faulty
      ones off with `exclude`
    '';

    exclude = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[01]\\.[01]\\.[0-4]");
      default = [ ];
      example = [ "1.0.4" ];
      description = ''
        Pairs of compute units to keep off, as bc250-cu-live-manager reports
        them: shader engine, shader array and pair number.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.hardware.bc250.driverPatch.enable;
        message = "hardware.bc250.cuUnlock needs the patched amdgpu driver (hardware.bc250.driverPatch.enable).";
      }
    ];

    boot.kernelParams = [
      "amdgpu.bc250_cc_write_mode=3"
    ]
    ++
      lib.optional (cfg.exclude != [ ])
        "amdgpu.disable_cu=${lib.concatMapStringsSep "," toUnit cfg.exclude}";
  };
}
