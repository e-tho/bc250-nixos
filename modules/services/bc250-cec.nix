{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.bc250-cec;
  libexec = "${cfg.package}/libexec/bc250-cec";

  toValue = value: if lib.isBool value then (if value then "1" else "0") else toString value;

  # The udev rule only covers remotes that appear later.
  applyRemoteKeys = pkgs.writeShellScript "bc250-cec-remote-keys" ''
    for rc in /sys/class/rc/rc*; do
      [ -e "$rc" ] && ${libexec}/bc250-cec-keymap.sh "''${rc##*/}" || true
    done
  '';
in
{
  options.services.bc250-cec = {
    enable = lib.mkEnableOption ''
      the BC-250 CEC service, for DP-to-HDMI adapters that tunnel CEC. It
      identifies the board on the CEC bus, retrains the DisplayPort link
      when the display turns on or switches to the board, and maps the TV
      remote's OK and Back to Enter and Esc
    '';

    package = lib.mkPackageOption pkgs "bc250-cec" { };

    settings = lib.mkOption {
      type =
        with lib.types;
        attrsOf (oneOf [
          bool
          int
          str
        ]);
      default = { };
      example = {
        BC250_CEC_SWITCH_INPUT_ON_POWER_ON = true;
      };
      description = ''
        Keys for {file}`/etc/bc250-cec.conf`, as listed in the package's
        {file}`share/doc/bc250-cec/bc250-cec.conf`. Unset ones keep the
        daemon's defaults.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Read by the service and by the keymap script udev runs.
    environment.etc."bc250-cec.conf".text = lib.concatStrings (
      lib.mapAttrsToList (name: value: "${name}=${toValue value}\n") cfg.settings
    );

    services.udev.packages = [ cfg.package ];

    systemd.services.bc250-cec = {
      description = "BC-250 CEC service";
      # The CEC adapter appears once amdgpu has brought up the display.
      after = [ "graphical.target" ];
      wantedBy = [ "graphical.target" ];
      restartTriggers = [ config.environment.etc."bc250-cec.conf".source ];
      serviceConfig = {
        EnvironmentFile = "/etc/bc250-cec.conf";
        ExecStartPre = applyRemoteKeys;
        ExecStart = "${libexec}/bc250-cec-daemon.sh";
        Restart = "on-failure";
        RestartSec = 10;
        RuntimeDirectory = "bc250-cec";
      };
    };
  };
}
