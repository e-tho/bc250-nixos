# Rebuilds only the kernel modules the patch series changes, against the
# running kernel. The modules are worked out from the files the patches
# touch; a patch changing anything outside a known module fails the build.
{
  lib,
  kernel,
  linux-cachyos-bc250-src,
  bc,
  bison,
  flex,
  python3,
  zlib,
}:

let
  manifest = lib.importJSON ../linux-cachyos-bc250/manifest.json;
in
kernel.stdenv.mkDerivation {
  pname = "bc250-kernel-modules";
  version = "${kernel.version}-${manifest.version}";

  inherit (kernel) src;

  # The patches nixpkgs applies to the running kernel, so the modules are
  # built from the same source.
  patches = map (p: p.patch) (
    lib.filter (p: (p.patch or null) != null) (kernel.kernelPatches or [ ])
  );

  nativeBuildInputs = kernel.moduleBuildDependencies ++ [
    bc
    bison
    flex
    python3
  ];

  # Needed to prepare the kernel tree for building modules.
  buildInputs = [ zlib ];

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

    make -j"$NIX_BUILD_CORES" modules_prepare
    while read -r dir; do
      make -j"$NIX_BUILD_CORES" M="$dir" modules
    done < module-dirs

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    while read -r dir; do
      make INSTALL_MOD_PATH="$out" XZ="xz -T$NIX_BUILD_CORES" M="$dir" modules_install
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
