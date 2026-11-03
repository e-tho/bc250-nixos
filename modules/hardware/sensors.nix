{ config, pkgs, ... }:

let
  # Built with the plain package set of the kernel's nixpkgs, as the binary
  # cache does not cover the kernel's own build environment.
  buildModule =
    path:
    pkgs.bc250-kernelBuildPackages.callPackage path {
      inherit (config.boot.kernelPackages) kernel;
    };
in
{
  boot.extraModulePackages = [
    (buildModule ../../pkgs/nct6687d)
  ];
  boot.kernelModules = [ "nct6687" ];
  boot.extraModprobeConfig = ''
    options nct6687 force=true
  '';
}
