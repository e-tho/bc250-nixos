{
  writeShellApplication,
  coreutils,
  curl,
  git,
  jq,
  nix,
}:

writeShellApplication {
  name = "update-linux-cachyos-bc250-src";

  runtimeInputs = [
    coreutils
    curl
    git
    jq
    nix
  ];

  # Takes the manifest path and updates the source pin; the kernel branch is
  # left unchanged. Expects to run from the project root, so the kernel check
  # uses this project's pinned nixpkgs.
  text = ''
    manifest=''${1:?usage: update-linux-cachyos-bc250-src <manifest.json>}
    owner=MastaG
    repo=linux-cachyos-bc250

    kernel=$(jq -r .kernel "$manifest")
    if ! nix eval --raw --inputs-from . "nixpkgs#linuxPackages_$kernel.kernel.version" >/dev/null; then
      echo "error: nixpkgs no longer has linuxPackages_$kernel; set the kernel the series now targets in $manifest" >&2
      exit 1
    fi

    rev=$(git ls-remote "https://github.com/$owner/$repo" HEAD | cut -f1)
    if [ "$rev" = "$(jq -r .rev "$manifest")" ]; then
      echo "$repo is already at $rev"
      exit 0
    fi

    hash=$(nix flake prefetch --json "github:$owner/$repo/$rev" | jq -r .hash)
    date=$(curl -fsSL "https://api.github.com/repos/$owner/$repo/commits/$rev" \
      | jq -r '.commit.committer.date[:10]')

    jq --arg version "0-unstable-$date" --arg rev "$rev" --arg hash "$hash" \
      '.version = $version | .rev = $rev | .hash = $hash' \
      "$manifest" > "$manifest.tmp"
    mv "$manifest.tmp" "$manifest"
    echo "$repo: updated to $rev"
  '';
}
