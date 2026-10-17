{
  lib,
  stdenv,
  fetchFromGitHub,
}:

stdenv.mkDerivation {
  pname = "bc250-memcfg";
  version = "0.1-unstable-2026-09-11";

  src = fetchFromGitHub {
    owner = "fanoush";
    repo = "bc250_memcfg";
    rev = "222420fbaeedadb7894fb0a782bdb61fa7b084af";
    hash = "sha256-2+CbxQIoKMTDA+Oz3JhKg5q3YVY8OdaU32qqzFu4/zM=";
  };

  buildPhase = ''
    runHook preBuild
    $CXX -Os main.cpp -o bc250memcfg
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 bc250memcfg "$out/bin/bc250memcfg"
    runHook postInstall
  '';

  meta = {
    description = "Tool to set the AMD BC-250 memory configuration stored in CMOS";
    homepage = "https://github.com/fanoush/bc250_memcfg";
    platforms = lib.platforms.linux;
    mainProgram = "bc250memcfg";
  };
}
