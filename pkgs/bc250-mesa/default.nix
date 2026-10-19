{
  lib,
  fetchurl,
  mesa,
  linux-cachyos-bc250-src,
}:

let
  pin = (lib.importJSON ../linux-cachyos-bc250/manifest.json).mesa;
in
mesa.overrideAttrs (prev: {
  pname = "bc250-mesa";
  # The version the patch series targets, which can lag behind the one
  # nixpkgs ships.
  inherit (pin) version;

  src = fetchurl {
    url = "https://archive.mesa3d.org/mesa-${pin.version}.tar.xz";
    inherit (pin) hash;
  };

  postPatch = ''
    for patch in ${linux-cachyos-bc250-src}/patches/mesa/*.patch; do
      echo "applying $(basename "$patch")"
      patch -p1 < "$patch"
    done
  ''
  + (prev.postPatch or "");

  meta = prev.meta // {
    description = "Mesa with the AMD BC-250 patch series";
    longDescription = ''
      Exposes the GPU's compute queue and adds DirectMesh and FSR4
      improvements. Hangs the GPU unless the amdgpu driver from the same
      series is running.
    '';
  };
})
