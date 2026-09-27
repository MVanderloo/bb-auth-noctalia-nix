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

  meta = {
    description = "Noctalia authentication UI provider for bb-auth";
    homepage = "https://github.com/branrgx/noctalia-plugins/tree/main/bb-auth";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
}
