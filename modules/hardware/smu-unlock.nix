{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.hardware.bc250;
  package = pkgs.bc250-smu-unlock;

  # The patch addresses only hold for this BIOS version.
  supportedBios = "P3.00";

  apply = pkgs.writeShellScript "bc250-smu-unlock" ''
    # The driver decodes the 8-core layout only when it finds 8 cores, which
    # the core unlock may not have brought up.
    read -r cpus < /sys/devices/system/cpu/present
    if [ "$cpus" = 0-11 ]; then
      echo "Skipping the SMU patch, since only 6 cores are present."
      exit 0
    fi

    read -r version < /sys/class/dmi/id/bios_version
    case "$version" in
      *${supportedBios}*) exec ${lib.getExe package} ;;
      *) echo "<3>Skipping the SMU patch, which needs BIOS ${supportedBios} (found $version). With 8 cores, the GPU driver misreads all metrics, including the temperature used for thermal throttling; disable the core unlock or the patched drivers." ;;
    esac
  '';
in
{
  options.hardware.bc250.smuUnlock.enable = lib.mkOption {
    type = lib.types.bool;
    internal = true;
    default = cfg.coreUnlock.enable && cfg.driverPatch.enable;
    description = ''
      Whether to report metrics for 8 cores, by patching the SMU firmware at
      boot. Needs the core unlock, and the patched driver to read the wider
      metrics.
    '';
  };

  config = lib.mkIf cfg.smuUnlock.enable {
    boot.initrd.systemd.enable = lib.mkDefault true;

    # The initrd copies these paths and the libraries their binaries link
    # to, but not the interpreters the scripts refer to.
    boot.initrd.systemd.storePaths = [
      apply
      package
      pkgs.bash
      pkgs.python3
    ];

    boot.initrd.systemd.services.bc250-smu-unlock = {
      description = "Patch BC-250 SMU firmware memory";
      wantedBy = [ "initrd.target" ];
      after = [ "bc250-core-unlock.service" ];
      # Runs before the GPU driver loads, since it picks its metrics layout
      # then.
      before = [
        "initrd-root-device.target"
        "systemd-udevd.service"
        "systemd-modules-load.service"
      ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        StandardOutput = "journal+console";
        StandardError = "journal+console";
        ExecStart = apply;
      };
    };
  };
}
