# Source of the kernel and Mesa patch series. update.nix keeps the pin in
# manifest.json current; `kernel` names the nixpkgs kernel branch the series
# targets and is changed by hand when the series moves to a new kernel.
{ lib, fetchFromGitHub }:

let
  manifest = lib.importJSON ./manifest.json;
in
fetchFromGitHub {
  owner = "MastaG";
  repo = "linux-cachyos-bc250";
  inherit (manifest) rev hash;
}
