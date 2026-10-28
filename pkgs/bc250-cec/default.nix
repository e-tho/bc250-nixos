# The CEC daemon and remote keymap from the linux-cachyos-bc250
# repository.
{
  lib,
  stdenvNoCC,
  makeWrapper,
  linux-cachyos-bc250-src,
  bash,
  coreutils,
  gnugrep,
  gnused,
  python3,
  v4l-utils,
}:

let
  manifest = lib.importJSON ../linux-cachyos-bc250/manifest.json;
  # The daemon injects its wake keypress through python-evdev.
  python = python3.withPackages (ps: [ ps.evdev ]);
in
stdenvNoCC.mkDerivation {
  pname = "bc250-cec";
  inherit (manifest) version;

  src = "${linux-cachyos-bc250-src}/packages/bc250-cec";

  nativeBuildInputs = [ makeWrapper ];
  # The scripts' shebangs are patched against this bash.
  buildInputs = [ bash ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    libexec=$out/libexec/bc250-cec
    install -Dm755 -t "$libexec" bc250-cec-daemon.sh bc250-cec-keymap.sh
    for script in bc250-cec-daemon.sh bc250-cec-keymap.sh; do
      wrapProgram "$libexec/$script" \
        --prefix PATH : ${
          lib.makeBinPath [
            coreutils
            gnugrep
            gnused
            python
            v4l-utils
          ]
        }
    done

    install -Dm644 71-bc250-cec-keys.rules $out/lib/udev/rules.d/71-bc250-cec-keys.rules
    substituteInPlace $out/lib/udev/rules.d/71-bc250-cec-keys.rules \
      --replace-fail /usr/lib/bc250-cec "$libexec"

    # The settings reference.
    install -Dm644 bc250-cec.conf $out/share/doc/bc250-cec/bc250-cec.conf

    runHook postInstall
  '';

  meta = {
    description = "HDMI CEC service for the AMD BC-250, retraining the display link when the display turns on";
    homepage = "https://github.com/MastaG/linux-cachyos-bc250/tree/main/packages/bc250-cec";
    license = lib.licenses.gpl2Only;
    platforms = lib.platforms.linux;
  };
}
