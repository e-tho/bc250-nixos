# UGREEN's updater and the five images for CH7218-based DP-to-HDMI 2.1
# adapters, behind MastaG's manual flash wrapper, from the
# linux-cachyos-bc250 repository.
{
  lib,
  stdenvNoCC,
  makeWrapper,
  linux-cachyos-bc250-src,
  bash,
  coreutils,
  gawk,
  glibc,
  gnugrep,
  gnused,
  python3,
  util-linux,
}:

let
  manifest = lib.importJSON ../linux-cachyos-bc250/manifest.json;
in
stdenvNoCC.mkDerivation {
  pname = "bc250-ch7218-fw";
  inherit (manifest) version;

  src = "${linux-cachyos-bc250-src}/packages/bc250-ch7218-fw";

  nativeBuildInputs = [ makeWrapper ];
  # The wrapper's shebang is patched against this bash.
  buildInputs = [ bash ];

  dontConfigure = true;
  dontBuild = true;
  # The updater must stay byte-identical to UGREEN's.
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    (cd firmware && sha256sum -c --quiet SHA256SUMS)

    libexec=$out/libexec/bc250-ch7218-fw
    install -Dm755 ch7218_fwu "$libexec/vendor/ch7218_fwu"
    # Started through the loader, since the binary's interpreter path
    # does not exist on NixOS and patching it would modify the binary.
    makeWrapper ${glibc}/lib/ld-linux-x86-64.so.2 "$libexec/ch7218_fwu" \
      --add-flags "$libexec/vendor/ch7218_fwu"

    install -Dm644 -t $out/share/bc250-ch7218-fw/firmware firmware/*
    install -Dm644 README.md $out/share/doc/bc250-ch7218-fw/README.md

    install -Dm755 bc250-ch7218-flash $out/bin/bc250-ch7218-flash
    # The wrapper verifies the images against the SHA256SUMS next to them,
    # so both directories are fixed to the package's.
    wrapProgram $out/bin/bc250-ch7218-flash \
      --set BC250_CH7218_LIBDIR "$libexec" \
      --set BC250_CH7218_IMGDIR $out/share/bc250-ch7218-fw/firmware \
      --prefix PATH : ${
        lib.makeBinPath [
          bash
          coreutils
          gawk
          gnugrep
          gnused
          python3
          util-linux
        ]
      }

    runHook postInstall
  '';

  meta = {
    description = "Firmware images and a manual flash command for UGREEN DP-to-HDMI 2.1 adapters (Chrontel CH7218A)";
    homepage = "https://github.com/MastaG/linux-cachyos-bc250/tree/main/packages/bc250-ch7218-fw";
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [
      binaryFirmware
      binaryNativeCode
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "bc250-ch7218-flash";
  };
}
