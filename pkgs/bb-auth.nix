{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  coreutils,
  qt6,
  kdePackages,
  polkit,
  gcr_3,
  gcr_4,
  glib,
  json-glib,
}:

stdenv.mkDerivation {
  pname = "bb-auth";
  version = "0.2.1-unstable-2026-08-31";

  src = fetchFromGitHub {
    owner = "branrgx";
    repo = "bb-auth";
    rev = "acd735022707b17c77d31030f170ef995717d334";
    hash = "sha256-64f34ALRMEjnAfAX97HS4CVgAmcxC+zC3D7w9QQ8EUQ=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
    qt6.wrapQtAppsHook
  ];
  buildInputs = [
    qt6.qtbase
    kdePackages.polkit-qt-1
    polkit
    gcr_4
    glib
    json-glib
  ];

  cmakeFlags = [
    (lib.cmakeFeature "BB_AUTH_GCR_PROMPTER_BINARY" "${gcr_3}/libexec/gcr-prompter")
  ];

  postPatch = ''
    # These tests check executable paths before calling their mock launcher.
    substituteInPlace tests/test_provider_launcher.cpp \
      --replace-fail /bin/true ${coreutils}/bin/true \
      --replace-fail /bin/false ${coreutils}/bin/false
  '';

  doCheck = true;

  # The daemon also dispatches pinentry/keyring by argv[0]. Only the separate
  # graphical fallback needs Qt's environment wrapper.
  dontWrapQtApps = true;
  postFixup = ''
    wrapQtApp "$out/libexec/bb-auth-fallback"
  '';

  postInstall = ''
    mkdir -p "$out/bin"
    for program in bb-auth pinentry-bb bb-keyring-prompter; do
      ln -s "../libexec/$program" "$out/bin/$program"
    done

    # Home Manager owns the service, GPG configuration and D-Bus activation.
    # Upstream's bootstrap mutates those files imperatively at each startup.
    rm "$out/libexec/bb-auth-bootstrap" "$out/lib/systemd/user/bb-auth.service"
  '';

  meta = {
    description = "Unified Polkit, keyring and pinentry authentication daemon";
    homepage = "https://github.com/branrgx/bb-auth";
    license = lib.licenses.bsd3;
    mainProgram = "bb-auth";
    platforms = lib.platforms.linux;
  };
}
