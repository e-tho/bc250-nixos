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
  version = "0.4.14-unstable-2026-10-02";

  src = fetchFromGitHub {
    owner = "filippor";
    repo = "cyan-skillfish-governor";
    rev = "7b08fdcf542d1edd82f3a9077c902038019c9842";
    hash = "sha256-9MLUtRVefOr4omMcW9QC3sYV+amPCyBgm6dmlJo9/bo=";
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
