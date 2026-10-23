{
  config,
  lib,
  pkgs,
  ...
}:

let
  package = pkgs.bc250-core-unlock;
in
{
  options.hardware.bc250.coreUnlock.enable = lib.mkEnableOption ''
    unlocking the 2 factory-disabled CPU cores. The unlock is reapplied on
    each cold boot and triggers a reboot. Adding `bc250.nocoreunlock` to
    the kernel command line skips it for one boot. The cores stay unlocked
    until a power-off, even after disabling this option or adding the
    parameter. Stress-test the extra cores before use
  '';

  config = lib.mkIf config.hardware.bc250.coreUnlock.enable {
    assertions = [
      {
        assertion = config.boot.initrd.systemd.enable;
        message = "hardware.bc250.coreUnlock runs in the initrd and needs boot.initrd.systemd.enable.";
      }
    ];

    boot.initrd.systemd.enable = lib.mkDefault true;

    # The initrd copies these paths and the libraries their binaries link
    # to, but not the shell and the tools the script refers to.
    boot.initrd.systemd.storePaths = [
      package
      pkgs.bash
      pkgs.coreutils
      pkgs.util-linux
    ];

    boot.initrd.systemd.services.bc250-core-unlock = {
      description = "Unlock BC-250 CPU cores";
      wantedBy = [ "initrd.target" ];
      # amdgpu counts the CPUs when it loads to pick its metrics layout, and
      # the SMU unlock uses the same register window.
      before = [
        "initrd-root-device.target"
        "systemd-udevd.service"
        "systemd-modules-load.service"
        "bc250-smu-patch.service"
      ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        StandardOutput = "journal+console";
        ExecStart = lib.getExe package;
      };
    };
  };
}
