# Proton builds with the upscaling payload, as the linux-cachyos-bc250
# repository publishes them. A tool is rebuilt only when its own inputs
# change, and the release keeps its newest three builds, so a pin stays
# fetchable until three newer builds of that tool are published.
{
  lib,
  stdenvNoCC,
  fetchurl,
  zstd,
  writeShellScript,
  python3,
  gtk4,
  graphene,
  pango,
  gdk-pixbuf,
  harfbuzz,
  glib,
  gobject-introspection,
  sdl3,
  libx11,
  pname,
}:

let
  manifest = lib.importJSON ../linux-cachyos-bc250/manifest.json;
  pin = manifest.proton.${pname};

  # bc250-fsr4-launch.py opens the bc250-fsr4-menu.py upscaler menu at
  # game launch, using python3 from the Steam client's environment, which
  # on NixOS does not include the menu's dependencies. The menu loads some
  # of them through ctypes, so they go on the library path.
  menuPython = writeShellScript "bc250-fsr4-menu-python" ''
    export GI_TYPELIB_PATH=${
      lib.makeSearchPathOutput "out" "lib/girepository-1.0" [
        gtk4
        graphene
        pango
        gdk-pixbuf
        harfbuzz
        glib
        gobject-introspection
      ]
    }''${GI_TYPELIB_PATH:+:$GI_TYPELIB_PATH}
    export LD_LIBRARY_PATH=${
      lib.makeLibraryPath [
        sdl3
        libx11
      ]
    }''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    exec ${python3.withPackages (ps: [ ps.pygobject3 ])}/bin/python3 "$@"
  '';
in
stdenvNoCC.mkDerivation {
  inherit pname;
  inherit (pin) version;

  src = fetchurl {
    url = "https://github.com/MastaG/linux-cachyos-bc250/releases/download/repo/${pname}-${pin.version}-x86_64.pkg.tar.zst";
    inherit (pin) hash;
  };

  nativeBuildInputs = [ zstd ];

  outputs = [
    "out"
    "steamcompattool"
  ];

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  # The tool runs inside the Steam Linux Runtime, and each launch checks
  # the payload against its pinned hashes, so nothing may be rewritten.
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    echo "${pname} is a Steam compatibility tool; add it to programs.steam.extraCompatPackages." > "$out"

    mkdir -p "$steamcompattool/licenses"
    tar --zstd -xf "$src" -C "$steamcompattool" --strip-components=5 \
      "usr/share/steam/compatibilitytools.d/${pname}"
    # The notices of the bundled components, kept with the tool as
    # upstream Proton does.
    tar --zstd -xf "$src" -C "$steamcompattool/licenses" --strip-components=4 \
      "usr/share/licenses/${pname}"

    substituteInPlace "$steamcompattool/bc250-fsr4-launch.py" \
      --replace-fail '"--", "python3", str(menu)]' '"--", "${menuPython}", str(menu)]'

    runHook postInstall
  '';

  meta = {
    description = "Proton with the AMD BC-250 upscaling payload, for programs.steam.extraCompatPackages";
    homepage = "https://github.com/MastaG/linux-cachyos-bc250/blob/main/docs/FSR4-PROTON.md";
    license = with lib.licenses; [
      bsd3
      mit
      unfreeRedistributable
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
