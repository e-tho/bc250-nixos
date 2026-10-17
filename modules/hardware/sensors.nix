{ config, ... }:

{
  boot.extraModulePackages = [ config.boot.kernelPackages.nct6687d ];
  boot.kernelModules = [ "nct6687" ];
  boot.extraModprobeConfig = ''
    options nct6687 force=true
  '';
}
