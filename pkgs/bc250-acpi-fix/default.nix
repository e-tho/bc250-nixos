{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  acpica-tools,
  cpio,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "bc250-acpi-fix";
  version = "1.1.1";

  src = fetchFromGitHub {
    owner = "e-tho";
    repo = "bc250-acpi-fix";
    rev = "v${finalAttrs.version}";
    hash = "sha256-GiDABg6ownyhlREmdVkRR29Y0iojsLqYYWuIx/NTd70=";
  };

  nativeBuildInputs = [
    acpica-tools
    cpio
  ];

  installPhase = ''
    runHook preInstall
    install -Dm644 acpi_override.cpio "$out/lib/firmware/acpi/acpi_override.cpio"
    runHook postInstall
  '';

  meta = {
    description = "CPU power management for the AMD BC-250";
    homepage = "https://github.com/e-tho/bc250-acpi-fix";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
})
