# Built against the running kernel, like the patched modules: see
# modules/hardware/sensors.nix.
{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
}:

let
  kmake = "make ${
    lib.escapeShellArgs (lib.filter (flag: !lib.hasPrefix "O=" flag) kernel.makeFlags)
  } -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "bc250-vrm";
  version = "1.1.0";
  name = "${finalAttrs.pname}-${finalAttrs.version}-${kernel.version}";

  src = fetchFromGitHub {
    owner = "Hexxeh";
    repo = "bc250-vrm-dkms";
    tag = "v${finalAttrs.version}";
    hash = "sha256-IP+31Vh9I8MBNZ55kzfoNMGSGRwlPjVkzQoYfDxWEvk=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;
  hardeningDisable = [
    "pic"
    "format"
  ];

  # The kernel's own make arguments select the compiler it was built with,
  # in place of the LLVM=1 the Makefile's own targets set. Some contain
  # spaces, so each is escaped rather than passed through makeFlags.
  buildPhase = ''
    runHook preBuild
    ${kmake} M="$PWD" -j"$NIX_BUILD_CORES" modules
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    ${kmake} M="$PWD" INSTALL_MOD_PATH="$out" INSTALL_MOD_STRIP=1 modules_install
    runHook postInstall
  '';

  meta = {
    description = "VRM sensors for the AMD BC-250";
    homepage = "https://github.com/Hexxeh/bc250-vrm-dkms";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
  };
})
