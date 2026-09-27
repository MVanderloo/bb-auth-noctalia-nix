{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.noctalia.bb-auth;
in
{
  options.programs.noctalia.bb-auth = {
    enable = lib.mkEnableOption "bb-auth authentication through Noctalia";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../pkgs/bb-auth.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ../pkgs/bb-auth.nix { }";
      description = "The bb-auth package, including its pinentry and D-Bus activation files.";
    };

    pluginPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ../pkgs/noctalia-bb-auth-plugin.nix { };
      defaultText = lib.literalExpression "pkgs.callPackage ../pkgs/noctalia-bb-auth-plugin.nix { }";
      description = "The Noctalia plugin catalog containing branrgx/bb-auth.";
    };

    gpgAgent.enable = lib.mkEnableOption "Home Manager's GPG agent with pinentry-bb" // {
      default = true;
    };
    keyring.enable = lib.mkEnableOption "bb-auth as the D-Bus keyring system prompter" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      (lib.hm.assertions.assertPlatform "programs.noctalia.bb-auth" pkgs lib.platforms.linux)
    ];

    home.packages = [ cfg.package ];

    programs.noctalia.enable = true;
    programs.noctalia.settings = {
      shell.polkit_agent = false;
      plugins = {
        enabled = [ "branrgx/bb-auth" ];
        # Do not take ownership of the user's official/community catalogs.
        source = [
          {
            name = "branrgx";
            kind = "path";
            location = "${cfg.pluginPackage}";
          }
        ];
      };
    };

    services.gpg-agent = lib.mkIf cfg.gpgAgent.enable {
      enable = true;
      pinentry = {
        package = cfg.package;
        program = "pinentry-bb";
      };
    };

    systemd.user.services.bb-auth = {
      Unit = {
        Description = "BB Auth - Noctalia authentication backend";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
        ConditionEnvironment = "WAYLAND_DISPLAY";
      };

      Service = {
        ExecStart = "${lib.getExe cfg.package} --daemon";
        Slice = "session.slice";
        Restart = "on-failure";
        RestartSec = 2;
        TimeoutStopSec = 5;
        UMask = "0077";
      };

      Install.WantedBy = [ config.wayland.systemd.target ];
    };

    xdg.dataFile = {
      "dbus-1/services/org.bb.auth.service".source =
        "${cfg.package}/share/dbus-1/services/org.bb.auth.service";

      "dbus-1/services/org.gnome.keyring.SystemPrompter.service" = lib.mkIf cfg.keyring.enable {
        source = "${cfg.package}/share/bb-auth/org.gnome.keyring.SystemPrompter.service";
      };
    };
  };
}
