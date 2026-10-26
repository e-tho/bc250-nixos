{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

let
  version = "0-unstable-2026-10-23";
in
rustPlatform.buildRustPackage {
  pname = "bc250-smu-patch";
  inherit version;

  src = fetchFromGitHub {
    owner = "e-tho";
    repo = "bc250-smu-patch";
    rev = "d706463ccc4164e4c518f3c62a4333e28f652b29";
    hash = "sha256-J9V/Q3AkNUD72JvQC8pAOmoBit1dd1YzO+kmo5tgM9s=";
  };

  cargoHash = "sha256-IJuoFh2CAuCKCe8fUtCjLT2e4nwS3lHRxUzzpYLKl5o=";

  meta = {
    description = "Patch the AMD BC-250 SMU firmware";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "bc250-smu-patch";
  };
}
