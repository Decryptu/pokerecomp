#!/usr/bin/env bash
# Rebuilds the AltStore/SideStore feed from the published releases, so every
# entry is derived from the asset it points at rather than kept by hand.
set -euo pipefail

repo="${1:-Decryptu/pokerecomp}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="$root/.github/altstore/source.json"
assets="https://raw.githubusercontent.com/$repo/main/.github/altstore"
icon="https://raw.githubusercontent.com/$repo/main/app_icon.png"

bundle=$(sed -n 's/^application\/bundle_identifier="\(.*\)"$/\1/p' "$root/export_presets.cfg" | head -1)
min_ios=$(sed -n 's/^application\/min_ios_version="\(.*\)"$/\1/p' "$root/export_presets.cfg" | head -1)

description=$(cat <<'TXT'
A native Godot 4 reimplementation of the Generation 2 Game Boy Color games: Gold, Silver and Crystal. Written from scratch in GDScript, not an emulator, a static recompilation or a disassembly.

No game data ships with the app. You supply your own cartridge dump, which is SHA-1 verified, decoded once into a cache, and then released.

Three challenge modes are built in, mods are supported, and the same save works on every platform pokerecomp runs on.
TXT
)

gh api "repos/$repo/releases" --paginate --jq '.[]' \
  | jq -s \
      --arg bundle "$bundle" --arg min "$min_ios" --arg icon "$icon" \
      --arg assets "$assets" --arg description "$description" '
    [ .[]
      | select(.draft | not)
      | . as $r
      | ($r.assets[] | select(.name | endswith("-ios.ipa"))) as $a
      | { version: ($r.tag_name | ltrimstr("v")),
          buildVersion: ($r.tag_name | ltrimstr("v")),
          date: $r.published_at,
          localizedDescription: $r.body,
          downloadURL: $a.browser_download_url,
          size: $a.size,
          minOSVersion: $min }
    ] as $versions
    | { name: "pokerecomp",
        identifier: $bundle,
        sourceURL: ($assets + "/source.json"),
        fediUsername: "decrypt",
        subtitle: "Gold, Silver and Crystal, rebuilt in Godot",
        description: $description,
        iconURL: $icon,
        headerURL: ($assets + "/banner.jpg"),
        website: "https://github.com/Decryptu/pokerecomp",
        tintColor: "#E0A138",
        apps: [
          { name: "pokerecomp",
            bundleIdentifier: $bundle,
            developerName: "Decryptu",
            subtitle: "Gold, Silver and Crystal, rebuilt in Godot",
            localizedDescription: $description,
            iconURL: $icon,
            tintColor: "#E0A138",
            category: "games",
            screenshots: [
              { imageURL: ($assets + "/screenshot-launcher.png"), width: 2304, height: 1062 },
              { imageURL: ($assets + "/screenshot-world.png"), width: 2304, height: 1062 },
              { imageURL: ($assets + "/screenshot-voxel.png"), width: 2304, height: 1062 }
            ],
            versions: $versions }
          # The app-level copy of the newest version, which is what a client
          # older than the versions array reads.
          + { version: $versions[0].version,
              versionDate: $versions[0].date,
              versionDescription: $versions[0].localizedDescription,
              downloadURL: $versions[0].downloadURL,
              size: $versions[0].size }
        ] }' > "$out"

jq -e '.apps[0].versions | length > 0' "$out" > /dev/null
echo "$out: $(jq '.apps[0].versions | length' "$out") versions, newest $(jq -r '.apps[0].version' "$out")"
