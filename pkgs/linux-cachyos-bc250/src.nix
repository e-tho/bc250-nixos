# Source of the kernel and Mesa patch series, at the revision
# manifest.json pins.
{ lib, fetchFromGitHub }:

let
  manifest = lib.importJSON ./manifest.json;
in
fetchFromGitHub {
  owner = "MastaG";
  repo = "linux-cachyos-bc250";
  inherit (manifest) rev hash;
}
