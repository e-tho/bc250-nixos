{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.cyan-skillfish-governor-smu;
  tomlFormat = pkgs.formats.toml { };

  # Merges the settings over the config the package installs: tables combine
  # key by key, and any other value replaces the installed one.
  configFile =
    pkgs.runCommand "cyan-skillfish-governor-smu-config.toml"
      {
        nativeBuildInputs = [
          pkgs.jq
          pkgs.remarshal
        ];
        settings = builtins.toJSON cfg.settings;
        passAsFile = [ "settings" ];
      }
      ''
        toml2json ${cfg.package}/share/cyan-skillfish-governor-smu/config.toml \
          | jq --slurpfile settings "$settingsPath" '. * $settings[0]' \
          | json2toml > "$out"
      '';
in
{
  options.services.cyan-skillfish-governor-smu = {
    enable = lib.mkEnableOption "the Cyan Skillfish GPU governor";

    package = lib.mkPackageOption pkgs "cyan-skillfish-governor-smu" { };

    settings = lib.mkOption {
      inherit (tomlFormat) type;
      default = { };
      example = lib.literalExpression ''
        {
          safe-points = [
            { frequency = 1000; voltage = 780; }
            { frequency = 2000; voltage = 940; }
          ];
        }
      '';
      description = ''
        Settings merged into the default config shipped by the governor. Each
        value set here replaces the shipped one. See the governor's README for
        the supported keys.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.etc."cyan-skillfish-governor-smu/config.toml".source = configFile;
    services.dbus.packages = [ cfg.package ];

    systemd.services.cyan-skillfish-governor-smu = {
      description = "Cyan Skillfish GPU Governor";
      wantedBy = [ "multi-user.target" ];
      wants = [ "dbus.service" ];
      after = [ "dbus.service" ];
      conflicts = [
        "cyan-skillfish-governor.service"
        "cyan-skillfish-governor-tt.service"
        "oberon-governor.service"
      ];
      restartTriggers = [ configFile ];
      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} /etc/cyan-skillfish-governor-smu/config.toml";
        ManagedOOMPreference = "avoid";
        OOMScoreAdjust = -1000;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };
  };
}
