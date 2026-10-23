# Packages that do not depend on the running kernel. The patched kernel
# modules are built from the kernel package set instead, see
# modules/hardware/driver-patch.nix.
final: prev: {
  bc250-acpi-fix = final.callPackage ./bc250-acpi-fix { };
  bc250-core-unlock = final.callPackage ./bc250-core-unlock { };
  bc250-cu-live-manager = final.callPackage ./bc250-cu-live-manager { };
  bc250-memcfg = final.callPackage ./bc250-memcfg { };
  bc250-mesa = final.callPackage ./bc250-mesa { };
  bc250-smu-oc = final.callPackage ./bc250-smu-oc { };
  bc250-smu-patch = final.callPackage ./bc250-smu-patch { };
  cyan-skillfish-governor-smu = final.callPackage ./cyan-skillfish-governor-smu { };
  linux-cachyos-bc250-src = final.callPackage ./linux-cachyos-bc250/src.nix { };
  proton-cachyos-slr-bc250 = final.callPackage ./bc250-proton { pname = "proton-cachyos-slr-bc250"; };
  protonge-latest-bc250 = final.callPackage ./bc250-proton { pname = "protonge-latest-bc250"; };
}
