{ lib, pkgs, ... }:

{
  imports = [
    ./config/swap.nix
    ./hardware/acpi-fix.nix
    ./hardware/core-unlock.nix
    ./hardware/cu-unlock.nix
    ./hardware/driver-patch.nix
    ./hardware/sensors.nix
    ./hardware/smu-patch.nix
    ./hardware/vram.nix
    ./services/bc250-cec.nix
    ./services/bc250-smu-oc.nix
    ./services/cyan-skillfish-governor-smu.nix
  ];

  nix.settings = {
    substituters = [ "https://bc250-nixos.cachix.org" ];
    trusted-public-keys = [ "bc250-nixos.cachix.org-1:sOceaxECzHXj5Qx+TMIm183ISclrIp3lGJTcxS/V+dQ=" ];
  };

  services.cyan-skillfish-governor-smu = {
    enable = lib.mkDefault true;
    # Lets the performance-mode script reach the governor.
    settings.dbus.enabled = lib.mkDefault true;
  };

  environment.systemPackages = [
    pkgs.bc250-cu-live-manager
    pkgs.bc250-memcfg
    pkgs.bc250-smu-oc
  ];

  # Proton uses it for Windows synchronization primitives when present.
  boot.kernelModules = [ "ntsync" ];
}
