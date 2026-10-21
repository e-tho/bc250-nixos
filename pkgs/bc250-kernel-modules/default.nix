# Rebuilds only the kernel modules the patch series changes, against the
# running kernel. The modules are worked out from the files the patches
# touch; a patch changing anything outside a known module fails the build.
{
  lib,
  stdenv,
  kernel,
  linux-cachyos-bc250-src,
  bc,
  bison,
  elfutils,
  flex,
  openssl,
  pahole,
  perl,
  python3,
  zlib,
  zstd,
}:

let
  manifest = lib.importJSON ../linux-cachyos-bc250/manifest.json;

  # The kernel's own make arguments select the compiler and tools it was
  # built with. The output directory is left out, as the modules are
  # built in the source tree.
  kmake = "make ${
    lib.escapeShellArgs (lib.filter (flag: !lib.hasPrefix "O=" flag) kernel.makeFlags)
  }";
in
stdenv.mkDerivation {
  pname = "bc250-kernel-modules";
  version = "${kernel.version}-${manifest.version}";

  inherit (kernel) src;

  # The patches applied to the running kernel, so the modules are built
  # from the same source.
  patches = map (p: p.patch) (
    lib.filter (p: (p.patch or null) != null) (kernel.kernelPatches or [ ])
  );

  nativeBuildInputs = [
    bc
    bison
    flex
    pahole
    perl
    python3
    zstd
  ];

  # Needed to prepare the kernel tree for building modules.
  buildInputs = [
    elfutils
    openssl
    zlib
  ];

  postPatch = (kernel.postPatch or "") + ''
    : > module-dirs
    for patch in ${linux-cachyos-bc250-src}/patches/linux-cachyos/*.patch; do
      echo "applying $(basename "$patch")"
      patch -p1 < "$patch"

      for file in $(sed -n 's|^+++ b/||p' "$patch"); do
        case "$file" in
          drivers/gpu/drm/amd/*) echo drivers/gpu/drm/amd/amdgpu >> module-dirs ;;
          drivers/crypto/ccp/*) echo drivers/crypto/ccp >> module-dirs ;;
          # Build-system entries for drivers this package does not build.
          */Kconfig | */Makefile) ;;
          *)
            echo "error: $(basename "$patch") changes $file, which is outside the modules this package builds" >&2
            exit 1
            ;;
        esac
      done
    done
    sort -u -o module-dirs module-dirs
  '';

  buildPhase = ''
    runHook preBuild

    patchShebangs scripts
    build=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build
    cp "$build/Module.symvers" "$build/.config" .
    cp ${kernel.dev}/vmlinux .

    ${kmake} -j"$NIX_BUILD_CORES" modules_prepare
    while read -r dir; do
      ${kmake} -j"$NIX_BUILD_CORES" M="$dir" modules
    done < module-dirs

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    while read -r dir; do
      ${kmake} INSTALL_MOD_PATH="$out" INSTALL_MOD_STRIP=1 M="$dir" modules_install
    done < module-dirs

    runHook postInstall
  '';

  meta = {
    description = "amdgpu and ccp kernel modules with the AMD BC-250 patch series";
    homepage = "https://github.com/MastaG/linux-cachyos-bc250";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
  };
}
