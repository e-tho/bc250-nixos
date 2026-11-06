{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  libdrm,
  util-linux,
  dbus,
}:

rustPlatform.buildRustPackage {
  pname = "cyan-skillfish-governor-smu";
  version = "0.4.15-unstable-2026-11-04";

  src = fetchFromGitHub {
    owner = "filippor";
    repo = "cyan-skillfish-governor";
    rev = "34cea69cdf617d1ad05edc71c4c61df501a13c8e";
    hash = "sha256-nt6M1rWv9eOC7ic3kcR3clggBZt3A37oCpk5q8Xban8=";
  };

  cargoHash = "sha256-zlAVGLGnub2Gc0Bkzb5GU9NBAJ2YWLhIG8JOa+1wHx8=";

  nativeBuildInputs = [
    pkg-config
    makeWrapper
  ];

  buildInputs = [
    libdrm
    dbus
  ];

  postInstall = ''
    wrapProgram "$out/bin/cyan-skillfish-governor-smu" \
      --prefix PATH : ${
        lib.makeBinPath [
          util-linux
          dbus
        ]
      }

    install -Dm644 default-config.toml "$out/share/cyan-skillfish-governor-smu/config.toml"
    install -Dm644 com.cyanskillfish.Governor.conf \
      "$out/share/dbus-1/system.d/com.cyanskillfish.Governor.conf"

    install -Dm755 scripts/cyan-skillfish-performance-mode "$out/bin/cyan-skillfish-performance-mode"
    wrapProgram "$out/bin/cyan-skillfish-performance-mode" \
      --prefix PATH : ${lib.makeBinPath [ dbus ]}
  '';

  meta = {
    description = "GPU governor for the AMD Cyan Skillfish APU";
    homepage = "https://github.com/filippor/cyan-skillfish-governor";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "cyan-skillfish-governor-smu";
  };
}
