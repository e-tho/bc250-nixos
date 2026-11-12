# Built against the running kernel: see modules/hardware/sensors.nix.
{
  lib,
  stdenv,
  fetchFromGitHub,
  kernel,
}:

let
  # The kernel's own make arguments select the compiler it was built with.
  # Some contain spaces, so each is escaped.
  kmake = "make ${
    lib.escapeShellArgs (lib.filter (flag: !lib.hasPrefix "O=" flag) kernel.makeFlags)
  } -C ${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";
in
stdenv.mkDerivation (finalAttrs: {
  pname = "nct6687d";
  version = "0-unstable-2026-11-12";
  name = "${finalAttrs.pname}-${finalAttrs.version}-${kernel.version}";

  src = fetchFromGitHub {
    owner = "Fred78290";
    repo = "nct6687d";
    rev = "6c639927352c92211edd72586c966e34dffc1d1e";
    hash = "sha256-7yu09t5gn7Ov6iH0ERxV3v0w83fbwzz4vEIvXKM6ol0=";
  };

  nativeBuildInputs = kernel.moduleBuildDependencies;
  hardeningDisable = [
    "pic"
    "format"
  ];

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
    description = "Kernel module for the Nuvoton NCT6687-R Super I/O";
    homepage = "https://github.com/Fred78290/nct6687d";
    license = lib.licenses.gpl2Only;
    platforms = [ "x86_64-linux" ];
  };
})
