{ pkgs, home-manager }:

let
  inherit (pkgs) lib;
  evaluate =
    extra:
    (home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ../modules/home-manager.nix
        {
          home.username = "review";
          home.homeDirectory = "/home/review";
          home.stateVersion = "26.05";
        }
        extra
      ];
    }).config;
  enabledWith =
    extra:
    evaluate {
      imports = [ extra ];
      programs.noctalia.bb-auth.enable = true;
    };

  disabled = evaluate { };
  enabled = enabledWith { };
  optOut = enabledWith {
    programs.noctalia.bb-auth = {
      gpgAgent.enable = false;
      keyring.enable = false;
    };
  };
  existing = enabledWith {
    programs.noctalia.bb-auth.gpgAgent.enable = false;
    services.gpg-agent = {
      enable = true;
      pinentry.package = pkgs.pinentry-curses;
    };
    programs.noctalia.settings.plugins = {
      enabled = [ "example/other" ];
      source = [
        {
          name = "official";
          kind = "git";
          location = "https://github.com/noctalia-dev/official-plugins";
        }
      ];
    };
  };
  session = enabledWith { wayland.systemd.target = "custom-session.target"; };
  override = enabledWith {
    programs.noctalia.bb-auth = {
      package = pkgs.hello;
      pluginPackage = pkgs.emptyDirectory;
    };
  };
  keyringFile = "dbus-1/services/org.gnome.keyring.SystemPrompter.service";
  gpgFile = "${enabled.home.homeDirectory}/.gnupg/gpg-agent.conf";

  tests = {
    disabledIsInert =
      !(disabled.systemd.user.services ? bb-auth)
      && !(disabled.xdg.dataFile ? "dbus-1/services/org.bb.auth.service")
      && !(builtins.hasAttr keyringFile disabled.xdg.dataFile)
      && !disabled.services.gpg-agent.enable
      && !disabled.programs.noctalia.enable
      && disabled.programs.noctalia.settings == { };
    configurationsAreValid = builtins.all (c: builtins.all (a: a.assertion) c.assertions) [
      disabled
      enabled
      optOut
      existing
      session
      override
    ];
    oneSwitchEnablesNoctalia = enabled.programs.noctalia.enable;
    gpgIntegrationIsDefault =
      enabled.services.gpg-agent.enable
      && enabled.services.gpg-agent.pinentry.package == enabled.programs.noctalia.bb-auth.package
      && enabled.services.gpg-agent.pinentry.program == "pinentry-bb"
      && builtins.hasAttr gpgFile enabled.home.file;
    keyringIntegrationIsDefault = builtins.hasAttr keyringFile enabled.xdg.dataFile;
    optOutsWork =
      !optOut.services.gpg-agent.enable
      && !(builtins.hasAttr keyringFile optOut.xdg.dataFile)
      && optOut.programs.noctalia.enable
      && optOut.systemd.user.services ? bb-auth;
    existingAgentIsPreserved = existing.services.gpg-agent.pinentry.package == pkgs.pinentry-curses;
    catalogsCompose =
      lib.sort builtins.lessThan (map (s: s.name) existing.programs.noctalia.settings.plugins.source) == [
        "branrgx"
        "official"
      ];
    pluginsCompose =
      lib.sort builtins.lessThan existing.programs.noctalia.settings.plugins.enabled == [
        "branrgx/bb-auth"
        "example/other"
      ];
    sessionTarget =
      session.systemd.user.services.bb-auth.Unit.PartOf == [ "custom-session.target" ]
      && session.systemd.user.services.bb-auth.Unit.After == [ "custom-session.target" ]
      && session.systemd.user.services.bb-auth.Install.WantedBy == [ "custom-session.target" ];
    packageOverrides =
      override.systemd.user.services.bb-auth.Service.ExecStart == [ "${lib.getExe pkgs.hello} --daemon" ]
      && override.services.gpg-agent.pinentry.package == pkgs.hello
      &&
        (builtins.head override.programs.noctalia.settings.plugins.source).location
        == "${pkgs.emptyDirectory}";
    polkitAgentIsReplaced = !enabled.programs.noctalia.settings.shell.polkit_agent;
  };
  failures = builtins.attrNames (lib.filterAttrs (_: passed: !passed) tests);
in
assert lib.assertMsg (
  failures == [ ]
) "bb-auth Home Manager checks failed: ${lib.concatStringsSep ", " failures}";
pkgs.runCommand "bb-auth-home-manager-checks" { } ''
  # Building these files also invokes Home Manager's Noctalia config validator.
  test -s ${enabled.xdg.configFile."noctalia/config.toml".source}
  test -s ${existing.xdg.configFile."noctalia/config.toml".source}
  grep -F 'pinentry-program ${enabled.programs.noctalia.bb-auth.package}/bin/pinentry-bb' \
    ${enabled.home.file.${gpgFile}.source}
  test -f ${enabled.xdg.dataFile.${keyringFile}.source}
  test -f ${enabled.xdg.dataFile."dbus-1/services/org.bb.auth.service".source}
  touch "$out"
''
