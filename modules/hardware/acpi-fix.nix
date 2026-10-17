{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.hardware.bc250.acpiFix.enable = lib.mkEnableOption ''
    CPU frequency scaling and idle states, through corrected ACPI tables.
    Conflicts with the tables some modded BIOSes inject
  '' // { default = true; };

  config = lib.mkIf config.hardware.bc250.acpiFix.enable {
    boot.initrd.prepend = [ "${pkgs.bc250-acpi-fix}/lib/firmware/acpi/acpi_override.cpio" ];
  };
}
