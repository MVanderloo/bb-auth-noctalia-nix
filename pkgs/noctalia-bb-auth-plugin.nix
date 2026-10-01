{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  python3,
}:

stdenvNoCC.mkDerivation {
  pname = "noctalia-bb-auth";
  version = "1.1.1";

  src = fetchFromGitHub {
    owner = "branrgx";
    repo = "noctalia-plugins";
    rev = "409d26d29faae6ed2fa1cbd44efba3d8f0eaa097";
    hash = "sha256-e7/A5VuzKkgp3RM1JtwfNqioi+S1SGAJ1QlUIE18Ub8=";
  };

  dontBuild = true;

  postPatch = ''
    # Newer Noctalia v5 builds require a minimum shell version, not just
    # plugin_api. Retain plugin_api for older API-23 builds.
    substituteInPlace bb-auth/plugin.toml \
      --replace-fail 'plugin_api = 23' 'plugin_api = 23
    min_noctalia = "5.0.0"'

    substituteInPlace bb-auth/service.luau \
      --replace-fail '"python3 "' '"${python3}/bin/python3 "'

    substituteInPlace bb-auth/panel.luau bb-auth/blocked.luau \
      --replace-fail '"python3",' '"${python3}/bin/python3",' \
      --replace-fail 'noctalia.pluginDataDir()' 'noctalia.getenv("XDG_RUNTIME_DIR")'

    # Prompt responses are transient secrets. Keep the handoff in the private
    # runtime directory, with names scoped to this plugin.
    substituteInPlace bb-auth/panel.luau \
      --replace-fail '.. filename' '.. "noctalia-bb-auth-" .. filename'

    substituteInPlace bb-auth/blocked.luau \
      --replace-fail '"/blocked-cancel.json"' '"/noctalia-bb-auth-blocked-cancel.json"'
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -r bb-auth catalog.toml "$out/"
    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ${python3}/bin/python3 - "$out/bb-auth" <<'PY'
    import pathlib
    import sys
    import tomllib

    plugin = pathlib.Path(sys.argv[1])
    manifest = tomllib.loads((plugin / "plugin.toml").read_text())
    assert manifest["id"] == "branrgx/bb-auth"
    assert manifest["name"]
    assert manifest["min_noctalia"] == "5.0.0"
    assert manifest["plugin_api"] == 23
    for kind in ("service", "panel"):
        for entry in manifest[kind]:
            assert (plugin / entry["entry"]).is_file(), entry
    PY
    runHook postInstallCheck
  '';

  meta = {
    description = "Noctalia authentication UI provider for bb-auth";
    homepage = "https://github.com/branrgx/noctalia-plugins/tree/main/bb-auth";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
