{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.bc250-smu-oc;
  iniFormat = pkgs.formats.ini { };
in
{
  options.services.bc250-smu-oc = {
    enable = lib.mkEnableOption "CPU overclocking and undervolting with bc250_smu_oc";

    package = lib.mkPackageOption pkgs "bc250-smu-oc" { };

    # Matches the file bc250-detect writes; the tool checks the ranges.
    settings.overclock = {
      frequency = lib.mkOption {
        type = lib.types.int;
        example = 3500;
        description = "Maximum CPU boost clock, in MHz.";
      };

      scale = lib.mkOption {
        type = lib.types.int;
        example = -35;
        description = "Offset to the CPU voltage curve; negative values undervolt.";
      };

      max_temperature = lib.mkOption {
        type = lib.types.int;
        example = 90;
        description = "Temperature limit for the CPU and the GPU, in °C.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    systemd.services.bc250-smu-oc = {
      description = "Apply BC-250 CPU overclock and undervolt settings";
      wantedBy = [ "multi-user.target" ];
      after = [ "systemd-modules-load.service" ];
      before = [ "cyan-skillfish-governor-smu.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${lib.getExe' cfg.package "bc250-apply"} --apply ${iniFormat.generate "overclock.conf" cfg.settings}";
      };
    };
  };
}
