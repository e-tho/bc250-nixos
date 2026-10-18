{
  writeShellApplication,
  coreutils,
  curl,
  gawk,
  gnugrep,
  jq,
  nix,
}:

writeShellApplication {
  name = "update-linux-cachyos-bc250";

  runtimeInputs = [
    coreutils
    curl
    gawk
    gnugrep
    jq
    nix
  ];

  # Takes the manifest path and updates the source revision and the
  # Proton builds paired with it: the revision the release workflow last
  # built, and the newest build of each tool at or below that run, since
  # builds carry the run number and tools are only rebuilt when their
  # inputs change. A run that fails before rebuilding a tool leaves it
  # paired with its previous build. The kernel branch is only checked,
  # against this project's nixpkgs, so this runs from the project root.
  text = ''
    manifest=''${1:?usage: update-linux-cachyos-bc250 <manifest.json>}
    owner=MastaG
    repo=linux-cachyos-bc250
    api="https://api.github.com/repos/$owner/$repo"
    tools=(proton-cachyos-slr-bc250 protonge-latest-bc250)

    kernel=$(jq -r .kernel "$manifest")
    if ! nix eval --raw --inputs-from . "nixpkgs#linuxPackages_$kernel.kernel.version" >/dev/null; then
      echo "error: nixpkgs no longer has linuxPackages_$kernel; set the kernel the series now targets in $manifest" >&2
      exit 1
    fi

    branch=$(curl -fsSL "$api" | jq -r .default_branch)
    latest=$(curl -fsSL "$api/actions/workflows/build-release.yml/runs?branch=$branch&status=completed&per_page=1" |
      jq -r '.workflow_runs[0] // empty | "\(.head_sha) \(.run_number) \(.head_commit.timestamp[:10])"')
    if [ -z "$latest" ]; then
      echo "error: no finished release build on $branch; nothing was updated" >&2
      exit 1
    fi
    read -r rev run date <<<"$latest"

    sums=$(curl -fsSL "https://github.com/$owner/$repo/releases/download/repo/SHA256SUMS")

    proton='{}'
    for tool in "''${tools[@]}"; do
      # The newest build of the tool at or below the run, as
      # "<sha256> <version>".
      pick=$(awk -v tool="$tool" -v run="$run" '
        {
          prefix = tool "-"
          suffix = "-x86_64.pkg.tar.zst"
          if (index($2, prefix) != 1 || substr($2, length($2) - length(suffix) + 1) != suffix) next
          version = substr($2, length(prefix) + 1, length($2) - length(prefix) - length(suffix))
          n = split(version, parts, "-")
          if (n != 2 || parts[2] !~ /^[0-9]+$/ || parts[2] + 0 > run + 0) next
          if (parts[2] + 0 > best) { best = parts[2] + 0; found = $1 " " version }
        }
        END { if (found) print found }
      ' <<<"$sums")
      if [ -z "$pick" ]; then
        echo "error: no $tool build at or before run $run; nothing was updated" >&2
        exit 1
      fi
      read -r sha version <<<"$pick"
      proton_hash=$(nix hash convert --hash-algo sha256 --to sri "$sha")
      proton=$(jq --arg tool "$tool" --arg version "$version" --arg hash "$proton_hash" \
        '. + {($tool): {version: $version, hash: $hash}}' <<<"$proton")
    done

    # shellcheck disable=SC2016
    filter='.proton = $proton'
    args=(--argjson proton "$proton")
    if [ "$rev" != "$(jq -r .rev "$manifest")" ]; then
      src_hash=$(nix flake prefetch --json "github:$owner/$repo/$rev" | jq -r .hash)
      # shellcheck disable=SC2016
      filter+=' | .version = $version | .rev = $rev | .hash = $hash'
      args+=(--arg version "0-unstable-$date" --arg rev "$rev" --arg hash "$src_hash")
    fi

    jq "''${args[@]}" "$filter" "$manifest" > "$manifest.tmp"
    mv "$manifest.tmp" "$manifest"
    echo "$repo: at $rev, with the Proton builds from run $run"
  '';
}
