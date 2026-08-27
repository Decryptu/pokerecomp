# Mods

A mod is interpreted GDScript in a directory under `user://mods/`. It is
interpreted because iOS forbids JIT and native code at runtime.

A mod never touches scene nodes or engine internals. It is handed a
`Gen2ModHost`, registers what it provides, and returns. It reads cartridge
content through `GameData` and live world state through `Gen2WorldAPI`. Both are
scene-free.

`GameRuntime` loads every installed mod before the first screen exists. The
launcher lists what loaded and names what it refused. A mod that fails to load is
reported through `Gen2ModHost.failures()` and skipped; the others still run.

A mod can be switched off without uninstalling it. `Gen2ModState` keeps the
disabled ids in `user://mods_disabled.json`. A disabled mod is still discovered
and still listed, it just does not run.

## Layout

```
user://mods/<id>/
  mod.json
  mod.gd
  icon.png        optional
  thumbnail.webp  optional
```

`mod.json`:

| Field | Meaning |
|---|---|
| `id` | Lowercase `[a-z0-9][a-z0-9_-]*`. Addresses the directory and the registry keys |
| `name` | Shown to the player |
| `version` | The mod's own version. Strict `major.minor.patch` |
| `api_version` | The contract this mod is written against. Current: `Gen2ModManifest.API_VERSION`, 21. A host accepts 1 to 21 |
| `entry` | A `.gd` path inside the mod directory, or inside the pack when there is one |
| `pack` | Optional `.pck` or `.zip` beside `mod.json`, holding the mod's files |
| `description` | Optional |
| `icon`, `thumbnail` | Optional paths, when the art is not at a conventional name |
| `dependencies` | Optional map of required mod ids to SemVer ranges |
| `games` | Optional list of cartridge ids: `gold`, `silver`, `crystal` |

Dependency ranges accept an exact version, `*`, wildcards (`1.x`, `1.4.*`),
comparison chains (`>=1.2.0 <2.0.0`), and caret or tilde ranges. Dependencies
load first. A missing, disabled, incompatible or failed dependency is refused by
name, and so is every member of a dependency cycle.

`games` absent or empty means every cartridge. A cartridge the mod does not name
refuses the mod at load, and the launcher's card shows the list before Play. An
id this host has never heard of is not refused when the manifest is read, so a
mod naming a future cartridge still installs.

An entry that is absolute, contains `..` or is not GDScript is refused before
anything runs. Manifests are read without executing mod code, so the launcher can
list what is installed and say why something was rejected.

### Packs

A mod may ship its scripts and resources in a resource pack instead of loose
files. `pack` names a `.pck` or `.zip` beside `mod.json`, exported from
`res://mods/<id>/`. `entry` is then a path inside that root:

```
user://mods/voxel/
  mod.json      { "pack": "content.zip", "entry": "mod.gd", ... }
  content.zip   mods/voxel/mod.gd, mods/voxel/renderer.gd, ...
```

`mod.json` stays a plain file, so the launcher can list and refuse a packed mod
without mounting it. The pack is mounted only when the mod loads, with
`replace_files` false, so it can add paths but never override the game's own. A
`pack` that is not a `.pck` or `.zip` file beside the manifest is refused when the
manifest is read.

### The entry script

```gdscript
extends RefCounted

func register(host: Gen2ModHost, manifest: Gen2ModManifest) -> void:
	host.register_world_renderer(manifest.id, load("%s/renderer.gd" % manifest.directory), "Voxel")
```

### Examples

Two example mods are in `mods/examples/`. Copy either into `user://mods/`.

| Mod | Shows |
|---|---|
| `voxel_preview/` | A world renderer. Switch it on from its launcher page, from the start menu's MODS entry, or with `V` in the overworld. It extrudes geometry from the same collision, block and palette data the 2D view reads, on the native layer, with a translucent text box and one registered setting |
| `new_content/` | Every non-renderer surface in one file: a type and two matchups, a species with its own art, a move, a move effect, an item with its pocket and mart shelf, a named control axis, a visible-encounter population, two rebalancing patches, both event channels and a presentation mutator |

The examples are excluded from every export preset. A distributed build ships the
loader and no mod.

## Installing

The launcher takes a `.zip` on every platform, through **Install** on its mods
page or by dropping the archive on the window. The archive holds one mod, at its
root or in a single folder:

```
voxel_preview.zip
  voxel_preview/
    mod.json
    mod.gd
```

An archive is refused whole if it has no `mod.json`, holds more than one mod
folder, declares an `api_version` this host does not answer, or names a path that
would write outside its own folder. Nothing is written until all of that passes,
so a refusal leaves what is installed untouched. Reimporting a mod that is present
asks first, and replacing one removes files the new version dropped.

An installed mod loads immediately, without a restart. So does a change to the
list: switching one on or off, deleting one, or choosing a different cartridge
reloads every mod against a fresh host. Mods load the same way in an exported
build as in the editor.

`user://mods/` is `app_userdata/pokerecomp/mods` on desktop, the app's
`Documents/mods` on iOS (visible in the Files app), and internal app storage on
Android.

### Headless runs

A headless run and a `-s` tool run load no mods, so a check, a test or a
screenshot measures the game rather than whatever is installed. Such a run still
discovers mods. Pass `--mods` for a run that is about a mod:

```bash
godot --headless --path . --quit-after 30 --mods
```

`--clock=HH:MM` pins the world clock for the run, over the export defaults and
over a save's own. `--clock=HH:MM:D` adds the day of the week. Use it to
photograph a renderer at a chosen hour through the production path.

```bash
godot --path . -s res://tools/preview_world.gd --clock=06:00 -- crystal 24 3 \
  /tmp/dawn.png live effects 20 8
```

## Icon and thumbnail

Both are optional. Dropping the file at the mod root is the whole of it.

| | File tried, in order | Size | Drawn by |
|---|---|---|---|
| Icon | `icon.png`, `icon.webp`, `icon.jpg` | 32x32, square | The launcher's list row and mod page |
| Thumbnail | `thumbnail.webp`, `thumb.webp`, `thumbnail.png`, `thumb.png` | 1280x720 | Nothing in the game; a listing site |

The manifest may name another path with `icon` or `thumbnail`, for art kept in a
subdirectory. The path must stay inside the mod folder; one that climbs out is
refused as `art_escapes_mod`.

An icon is drawn at a whole multiple of 32x32 with nearest filtering, so the
pixels stay square. Anything up to `Gen2ModArt.MAX_ICON_SIDE` is accepted and
never stretched. Past that, past a megabyte, or not a PNG, WebP or JPEG by its own
magic, it is ignored and the row keeps the generic glyph.

An index row may carry `icon` and `thumbnail` as https URLs, so a mod has a face
before it is installed. The launcher fetches each once and caches it under
`user://mod_icon_cache/`. An installed copy's own file always wins.

## Publishing a source

A source is a JSON feed listing mods that stay in their authors' repositories.
Anyone can publish one.

Every build follows this project's own source and nothing else. A feed is a
listing: following it installs nothing and downloads nothing until a mod is
picked out of it. Any other source is added by the player, because following one
means trusting whoever publishes it, and the built-in one is the only publisher
this project can answer for. It is part of the build and has no button to drop
it; every other source has one.

```json
{
  "schema_version": 1,
  "name": "Example mods",
  "mods": [
    {
      "id": "voxel_preview",
      "name": "Voxel Preview",
      "version": "1.0.0",
      "description": "Draws the map as geometry.",
      "games": ["gold", "silver", "crystal"],
      "download": "https://example.com/voxel_preview-1.0.0.zip",
      "icon": "https://example.com/voxel_preview/icon.png",
      "thumbnail": "https://example.com/voxel_preview/thumbnail.webp"
    }
  ]
}
```

- `schema_version` must be exactly the version the build reads.
- Feeds and downloads are https only.
- A row with no `id`, no usable `download`, or an illegal id is dropped; the rest
  of the listing still works. A bad `icon` or `thumbnail` costs only itself.
- `games` repeats the manifest's list so a listing says what a mod is for. Only
  the shape is checked. The manifest inside the archive still decides.

Pasting `owner/repo`, the repository page, a site root or the feed file all
resolve to the same feed: `https://<owner>.github.io/<repo>/index.json` for a
GitHub slug.

A listed mod installs through the same path an imported `.zip` does, and its
manifest id must match the one the feed advertised.

A row whose `version` is newer than the installed copy offers **Update** rather
than **Reinstall**. Both sides must be strict `major.minor.patch` numbers to
compare; anything else is reported as uncomparable.

Each feed's last listing that parsed is cached under `user://mod_index_cache/`.
The mod list is built from the cache, so it opens instantly and offline; the
network is asked on **Sources**, and once by the mod list itself for a source it
has no cached listing for at all. Unfollowing a source drops its cache.

The launcher groups the mod list by origin: a source that lists a mod's id owns
it, and a mod no source lists came from a file. Removing a source's mod
uninstalls it and leaves the row offering the download again. Removing a file's
mod deletes the only copy, and is confirmed first. A mod listed by two sources
belongs to the first source followed.

## Adding content

`mods/examples/new_content/` is every non-renderer surface in one file. Copy it
and read it beside this section.

A content number is per kind and starts at `Gen2ContentOverlay.FIRST_MOD_NUMBER`
(256). Every cartridge number fits in a byte, so a larger number is
unambiguously a mod's and means the same thing on all three cartridges. Five
kinds are numbered this way: `KIND_SPECIES`, `KIND_MOVE`, `KIND_ITEM`,
`KIND_TRAINER` and `KIND_TYPE`.

Types are the exception: the cartridge chart is zero-based, so
`patch_content(KIND_TYPE, id, 0, ...)` renames NORMAL, and a defined type still
sits past 256. A defined type must carry `name` and `physical`, because Gen II
splits physical and special by type number and a number past the chart has
nothing to compare against. Special is the default.

```gdscript
host.register_content(Gen2ContentOverlay.KIND_SPECIES, manifest.id, 256, {
	"name": "VOLTLING",
	"stats": {"speed": 115},
	"learnset": [{"level": 1, "move": 33}, {"level": 36, "move": 85}],
})
```

A definition is partial; whatever it leaves out comes from the kind's defaults.
Everything a species carries is a field on the one row, so its learnset,
evolution, egg moves and TM compatibility are part of the definition rather than
four more registrations. Every content read goes through `GameData._content()`,
so the engine reads a mod species exactly as it reads Pikachu.

Two mods claiming one number is refused and named rather than decided by load
order. `Gen2ContentOverlay.owner_of()` says which mod holds a number.

`species_count()`, `move_count()` and `trainer_count()` are the cartridge's own
runs. Mod numbers are listed with `Gen2ContentOverlay.defined_numbers(kind)`.

### Items that evolve

An item may name the evolution it causes, which is the one effect a definition
can give a field item:

```gdscript
host.register_content(Gen2ContentOverlay.KIND_ITEM, manifest.id, 256, {
	"name": "LINKING CORD",
	"field_menu": Gen2WorldPack.ITEMMENU_PARTY,
	"evolution": {"method": RomLayout.EVOLVE_TRADE},
})
```

The host runs that method's own predicate and then the whole of
`EvolveAfterBattle`'s tail, so the adapter, the HP delta, a consumed held item and
the new moves stay in one place. `EVOLVE_TRADE` and `EVOLVE_ITEM` are the two
methods available; an optional `"parameter"` is the stone `EVOLVE_ITEM` looks for,
defaulting to the item's own number. An item with no `evolution` behaves as before.

### Art

The pic atlases hold exactly the cartridge's slots, so a defined species or
trainer class supplies decoded indices instead: two bits a pixel, row-major, in
the same 0-3 index space the cache stores, and exactly `tiles * tiles * 64` of
them.

```gdscript
host.register_content(Gen2ContentOverlay.KIND_SPECIES, manifest.id, 256, {
	"name": "VOLTLING",
	"pics": {"front": {"tiles": 7, "indices": front}, "back": {"tiles": 6, "indices": back}},
	"icon": {"indices": strip},          # or a cartridge icon number, 1 to 38
	"palette": {"normal": [0x7FFF, 0x0000], "shiny": [0x7FFF, 0x0000]},
})
```

A species drawing its own `pics` stands still when sent out: the wobble is
`AnimateFrontpic`, whose frames the cartridge packs behind the picture. The cry
still plays.

A trainer class names one `pic` rather than two. An `icon` is the party menu's
strip, the eight tiles of its two 2x2 frames, or a cartridge icon number. Art left
out is not an error; `GameData.species_pic()` answers both kinds in one shape.

A mod species gets no Pokedex entry unless it replaces a cartridge one: both dex
order tables are cartridge data of exactly 251 entries. Mod content also cannot
leave the project's own save, because the hardware stores a species, item or move
in one byte; `Gen2SramAdapter` refuses to export a save carrying any of it.

### Patching cartridge rows

`patch_content()` changes a row the cartridge does have. Only the named fields
change, and a Dictionary field merges, so patching one stat leaves the others
alone. A patch of a number this cartridge lacks changes nothing rather than
inventing a row.

A type matchup is patched by its pair and is patch-only, since the cartridge chart
is a sparse table of exceptions and an absent pair is already neutral.
`multiplier` is in tenths, the way the damage formula divides.

```gdscript
host.patch_type_matchup(manifest.id, 256, RomLayout.TYPE_NORMAL, {
	"multiplier": RomLayout.MATCHUP_SUPER_EFFECTIVE,
})
```

`KIND_ENCOUNTER` and `KIND_FISHING` are the wild tables. They are patch-only,
since a mod can add neither a map nor a map header. Use the helpers rather than
counting table coordinates:

```gdscript
host.patch_encounter(manifest.id, &"grass", 3, 2, {
	"rate": 20,
	"slots": [[{"level": 50, "species": 1}], [], []],
})
host.patch_fishing_group(manifest.id, 1, {"rods": [...]})
```

The method is one of `grass`, `surf`, `swarm_grass` and `swarm_water`. `slots`
and `rates` replace whole. The patched row is what every reader gets, including
the region walk `FindNest` uses.

The four wild sources beside the map tables are patched by index:

| Helper | Row |
|---|---|
| `patch_treemon_set(id, set, fields)` | `GameData.treemon_set(set)`, shared by Headbutt and Rock Smash |
| `patch_bug_contest_mon(id, index, fields)` | One `ContestMons` row |
| `patch_roaming_mon(id, index, fields)` | One roaming Pokemon |
| `patch_fishing_time_group(id, index, fields)` | One day/night fishing substitution |

Name only what changes. A contest row's `percent` is both the choice weight and
part of the judging. A rod entry's `threshold` is the bite. A roaming mon's
`map_group`/`map_number` are where it is now, written by the roamer's own
movement, so a patch naming `species` and `level` leaves them alone.

## The gameplay catalog

Everything else a cartridge hands out is a site in a script or a map event, not a
table: a starter, a gift, a static battle, a trade, a Game Corner prize, an item
on the ground, a badge, a shop. `GameData.catalog()` decodes them once and gives
each a stable id, so a mod places rewards without holding a script address.

```gdscript
var catalog := data.catalog()
for row in catalog.rows(Gen2WorldCatalog.KIND_STATIC):
	host.patch_check(manifest.id, row["id"], {"species": 25, "level": 5})
```

| Kind | A row carries | Decoded from |
|---|---|---|
| `KIND_STARTER` | `species`, `level`, `item` | A `givepoke` whose script also shows the species with `pokepic`, which only Elm's three balls do |
| `KIND_GIFT` | `species`, `level`, `item` | Any other `givepoke` or `giveegg` |
| `KIND_PRIZE` | `species`, `level`, `price` | A give site that spends `takecoins`, priced by the branch's own take |
| `KIND_STATIC` | `species`, `level` | A `loadwildmon` with the `startbattle` that makes it one |
| `KIND_TRADE` | `trade`, `species`, `requested_species` | A `trade` command and the record it names |
| `KIND_ITEM` | `item`, `quantity`, `hidden` | `giveitem`, `verbosegiveitem`, an `itemball` object, a `hiddenitem` bg event |
| `KIND_BADGE` | `badge`, `engine_flag` | A `setflag` of a badge's engine flag |
| `KIND_SHOP` | `mart`, `dialog`, `items` | A `pokemart` command. `items` is the resolved shelf, `{item, price}` per row |

Every row also carries `id`, `kind`, its `bank` and `address` (or `map` and
`event_index`), the `map` it stands on where one could be attributed, and
`requires`: the events, engine flags and items the script tested before reaching
the site.

`patch_check(id, fields)` changes a field of a row. It cannot replace the script:
the site still sets its own flag, prints its own dialogue, takes its own money and
runs its own battle. Two mods patching one id is refused.

A field is effective at its whole transaction, not at one command:

| Patch | Also drives |
|---|---|
| a starter's `species` | the `pokepic` its ball shows |
| a prize's `price` | its `checkcoins` branch and its `takecoins` deduction |
| a trade's `species` / `requested_species` | both halves of the trade, carried beside the cartridge record so another site naming that record is unaffected |
| a shop's `items` | the shelf the counter sells |

The catalog is derived, not imported, so it needs no cache bump and no re-import.
`tools/checks/catalog.gd` pins both the census and the semantics on all three
cartridges.

### Proving a placement finishes

A shuffle of badges and key items can write a seed nobody can beat.
`host.validate_placement(data, patches)` answers before anything is installed:

```gdscript
var result := host.validate_placement(data, {check_id: {"item": hm_surf}, ...})
if not result["ok"]:
	print(result["missing"])   # {check, kind, requirement}
```

`patches` is the same `{check_id: fields}` shape `patch_check` takes. The answer
is `{ok, reached, critical, missing}`, deterministic, and it installs nothing, so
a generator retries against `missing`.

`missing.requirement` is `{map}`, `{item}` or `{badge}`: the first thing that
never became satisfiable. Behind it:

- `Gen2WorldReachability` floods each map's collision grid from the cells a player
  arrives on, asking the same tile questions the overworld does.
- An HM is a way past something only once its badge is in hand
  (`Gen2WorldFieldMove.badge_for_move`).
- `catalog.possible_starters()`, `catalog.field_hm_items()` and
  `catalog.is_progression(row)` are the same facts for a mod planning its own.

It does not model everything. It is map-granular rather than cell-exact, and story
`checkevent` guards are treated as satisfiable because a placement does not move
the scripts that set them. Both err toward passing a seed. A site with no
attributed map is taken as standing where the player already is.

## Adding a move effect

A move's effect byte is a number until something answers for it. `Gen2MoveEffect`
holds the cartridge's lists and `Gen2EffectCommands` the steps one is built from.
A registration is a list of steps.

```gdscript
host.register_move_effect(manifest.id, 0xF0, [
	Gen2EffectCommands.USED_MOVE_TEXT,
	Gen2EffectCommands.DO_TURN,
	Gen2EffectCommands.DAMAGE_CALC,
	Gen2EffectCommands.CHECK_HIT,
	Gen2EffectCommands.APPLY_DAMAGE,
	Gen2EffectCommands.RECOIL,
	Gen2EffectCommands.CHECK_FAINT,
	Gen2EffectCommands.END_MOVE,
])
```

A list naming an unknown step is refused at registration rather than mid-turn.
`register_effect_command()` adds a step of your own, a Callable taking the
`Gen2Turn`. It cannot take a name the engine already uses.

A registered effect replaces the cartridge's list for that byte, so a mod can
rewrite Sleep. `Gen2MoveEffect.RESERVED_EFFECTS` is the exception: the multi-hit,
fixed-damage, Rollout, Selfdestruct, time-based heal and two screen bytes are read
back off the turn by their own commands.

## Watching what happens

`subscribe(channel, id, handler)` on `Gen2ModHost.CHANNEL_WORLD` or
`CHANNEL_BATTLE` calls `handler` with each event dictionary as the screen reads
it, so a subscriber sees what the player sees, in order.

A subscriber only reads: the handler gets a copy and its return value is ignored.
Events are published from the screens, so a headless tool or a test driving the
engine directly fires none.

A capture is on the battle channel too, published with its `Gotcha!` line and so
before the nickname prompt. `Gen2Battle.CAUGHT` (`caught`) carries `species`,
`level`, `dvs`, `shiny`, `ball`, `method`, `map_group`, `map_number`,
`battle_type`, `destination` (`party` or `box`), `tutorial` and `contest`. The
last two are the catching tutorial and a Bug Contest catch: neither is a Pokemon
kept, which is why catch experience excludes both.

`register_event_mutator(channel, id, handler)` is the other half. The turn or the
script has already committed its state by then, so the handler may rewrite what is
*shown* (text, animation, display values) and returns a changed copy of the whole
event. Two limits: it cannot change the routing key (`type` on the battle channel,
`status` on the world one), and there is one mutator per channel, so the picture
never depends on load order. A handler returning anything else leaves the event
alone. Subscribers see the mutated event.

## Replacing the world renderer

Nothing about the world requires 2D drawing. Maps are node-free `RefCounted`
records, each tileset is one addressable atlas, animated tiles replace atlas slots
rather than map rectangles, and collision is a permission byte per 2x2 walk cell.
A renderer that extrudes geometry from that data is a registration, not a fork.

A registered renderer is a `Node` providing:

| Method | Called when |
|---|---|
| `set_world(world, animation)` | The map changed, or the view was created |
| `set_time_of_day(time_of_day)` | The clock crossed 04:00, 10:00 or 18:00 |
| `refresh()` | The player, an object or an event changed something |
| `refresh_animation()` | A tileset animation command changed tile data |

Registration is refused by name if any is missing or the script is not a `Node`.

Six methods are optional, on either renderer kind:

| Method | Effect |
|---|---|
| `uses_hardware_viewport() -> bool` | False moves the renderer off the 160x144 hardware viewport onto the screen's own rectangle at window resolution |
| `set_native_size(size: Vector2i)` | The native layer's size in window pixels, on creation and on every window change |
| `interface_opacity() -> float` | How opaque the screen draws the field of its text box, 0 to 1 |
| `set_text_box_rect(rect: Rect2i)` | Where that box is, in hardware pixels. Pushed on every change, empty when none is up |
| `set_interface_masked(masked: bool)` | A screen laid out in 160x144 has taken the picture, or given it back |
| `set_screen_rect(rect: Rect2i)` | Where the 160x144 screen sits inside the native layer. Pushed beside every `set_native_size` |

A view built out of geometry cannot be drawn into a 160x144 buffer and magnified,
so the native layer is what makes a 3D or HD renderer possible. Text boxes and
menus stay hardware pixels over the top: the world gains resolution, the interface
stays a Game Boy.

The box is drawn opaque. `interface_opacity()` asks for the field behind it to be
drawn through, and only the field: the frame and glyphs stay ink. Around 0.75
reads well over a map. It is honoured only for a renderer that answered
`uses_hardware_viewport()` false.

The world's own menus are not this box. The start menu, party and PC are
window-resolution panels with their own scrim, which a renderer neither sees nor
styles. The pack listing inside that panel is drawn by `Gen2PackPage` and is not
this box either. `Gen2MenuPage` is the cartridge box path, used by the naming and
gender screens, neither of which is ever over a renderer.

A world renderer has one more:

| Method | Effect |
|---|---|
| `handle_world_input(event: InputEvent) -> bool` | Every input event the world screen did not use. True consumes it |

The screen claims what it needs and offers the rest, so camera pitch, first person
and free-roam are reachable while a movement or interaction key never arrives: a
renderer reads world state and must not write it, and moving the player is writing
it. An open overlay, a running script, a battle or a trainer approach takes the
event first.

Implement this rather than Godot's `_input` or `_unhandled_input`, which would
race the gameplay keys instead of taking what is left of them.

### The tileset atlas

`GameData.world_tileset_indices(number)` is one tileset's graphics as an indexed
strip, `Gen2WorldTileset.tile_count` tiles wide and eight tall, one byte of colour
index per pixel. Every number a block can name indexes it directly:
`Gen2WorldTileset.tile_index(block, tile)` is the slot, and
`Gen2WorldPalette.tile_palettes()` answers one palette per slot in the same order.

The cartridge loads a tileset as two blocks of 96 tiles into separate VRAM banks,
and a metatile byte with the high bit set names the second. The strip carries both
at the cartridge's numbering: block 0 at 0-95, block 1 at 128-223, and the 32 tiles
between are the font's, always blank here. A tileset shipping one block leaves
128-223 blank.

`Gen2WorldAnimation` rewrites slots in this strip, so a renderer texturing from it
follows water and flowers for free. Geometry cut from the strip is cut from one
arbitrary frame, so `tile_frames(tile)` answers every frame a tile is ever drawn
as, in play order, each entry that tile's 64 palette indices row by row, with the
tileset's own tile first and an empty array for a tile no command touches. It does
not advance the live sequence. Ask it once per animated tile when a map resolves
and let a mesh span the union.

### Asking what a cell is

`Gen2WorldAPI.collision_code_at(cell)` is the raw cartridge byte, and
`Gen2WorldCollision` answers what the source asks of it. Read a predicate rather
than a tile number: a pin by drawing is per tile id and per tileset, and the
cartridge's answer is per cell.

| Call | Source |
|---|---|
| `permission_for(code)`, `is_walkable(code)` | `CollisionPermissionTable` |
| `talks(code)` | The same table's `TALK` bit |
| `grass_kind(code)`, `is_grass(code)`, `is_long_grass(code)` | `SetTallGrassFlags` |
| `allows_hop(code, direction)` | `.TryJump` |
| `is_warp_tile(code)`, `is_pit_tile(code)` | `CheckWarpCollision`, `CheckPitTile` |
| `side_wall_face_mask(code)` | `GetMovementPermissions` |

`grass_kind` returns `GRASS_NONE`, `GRASS_TALL` or `GRASS_LONG`: long grass is its
own pair of codes and the Bug Contest doubles its encounter rate. It is
`IN_GRASS_F`, not the encounter gate; `CheckGrassCollision` is that one and it
includes water.

### Blocks past the loaded map

`Gen2WorldAPI.drawn_block_at(x, y)` is the block a coordinate is *drawn* from
rather than the block stored there: `LoadMetatiles` substitutes the border block
for a `$00` byte, and `FillMapConnections` fills three blocks of padding around
the map with a neighbour's art.

A caller with no world reads the same fold through
`Gen2WorldAPI.drawn_block_for(data, map, x, y)`. That is what a battle has: a
`Gen2BattleWorldContext` names the map and hands over no world.
`tools/checks/drawn_blocks.gd` sweeps every map of every cache over its padded
rectangle and refuses a disagreement.

Live `changeblock` edits belong to the loaded world and are not visible to the
static form. `Gen2WorldAPI.block_revision` counts them, and a map load, so a view
caching the block buffer knows when to read it again.

`ChangeMap` copies a map into the middle of `wOverworldMapBlocks`, three blocks
wider on every side (`BUFFER_BLOCKS`). Past that margin the cartridge holds
nothing, which is why a 20x18 screen never needed more. A wider view walks the
connection graph instead, placing whole neighbouring maps in this map's block
coordinates.

| Call | Value |
|---|---|
| `map_placements() -> Dictionary` | `"group:number"` to `{map, origin}` for every map the graph reaches, nearest first. The loaded map is the origin and is not in it |
| `placements_around(data, map, hops) -> Dictionary` | The same for a map nobody is standing on |
| `connection_origin_blocks(source, target, connection) -> Vector2i` | Where one connection puts one map |
| `expanded_block_at(x, y) -> int` | `drawn_block_at` inside the buffer; past it, whichever placed map covers the coordinate, and the border block where none does |
| `in_hardware_buffer(map, x, y) -> bool` | Which of those two a coordinate takes |

`PLACEMENT_HOPS` and `PLACEMENT_LIMIT` bound the walk at three hops and 24 maps.

`expanded_block_at` is enough for a renderer with one tileset atlas only while it
stays in this map's tileset. A placed map is numbered in its *own* tileset, so a
block read across a boundary is a different picture with the same number. Read
`map_placements()` and compare `Gen2WorldMap.tileset` where that matters;
`GameData.world_tileset(number)` resolves the rest, and `Gen2WorldMap.blocks` and
`border_block` are public.

`connected_map_objects() -> Array` is the people standing on those maps, as
`{object, offset}` with the offset in walk cells. They are read-only copies and
deliberately not part of `Gen2WorldAPI.objects`: on the cartridge a connected map's
people do not exist until its own map load builds them. They take the event-flag
and visible-hours tests and nothing else. No step, no script, no sight, no
collision, no encounter, and they cannot be talked to.

## Framing the view

`Gen2WorldAPI` offers a camera; it does not impose one. A renderer framing its own
view can ignore all six calls.

| Method | Value |
|---|---|
| `player_position_cells() -> Vector2` | The committed cell plus any in-flight step, in walk cells |
| `visible_origin_cells() -> Vector2` | The framed view's top-left in fractional walk cells, centred on that position and clamped to the map |
| `visible_origin_cell() -> Vector2i` | The hardware page origin, which follows the committed cell |
| `view_pixels: Vector2i` | The drawn surface in hardware pixels, `VIEW_PIXELS` (160x144) unless a screen asked for more |
| `view_origin_pixels() -> Vector2` | That surface's top-left in world pixels |
| `player_view_pixel() -> Vector2i` | The player's pixel inside it |

The extra a wider surface adds is spread evenly around the screen the cartridge
would have drawn, so the player keeps the place `PLAYER_VIEW_CELL` puts him in.

`player_cell` commits at the start of a step, so the hardware page origin moves a
whole cell the instant one begins. A camera following it pans a step early;
`visible_origin_cells()` frames the interpolated position instead. The two agree
whenever no step is in flight.

The host constructs a renderer per world, so the view can change while the game
runs. `Gen2WorldScreen.select_view()` is that switch and `cycle_view()` is what
`V` is bound to. The map, the player and any running script are untouched.

## A screen that fills the window

A window is not the Game Boy's 10:9. **SCREEN FILL** (`Gen2Options.screen_fill`,
on by default, Settings > Application > Screen) grows the drawn surface to the
whole control instead of framing 160x144 inside it. Every screen takes it; what
differs is who fills it. The overworld fills it with more map. A screen laid out
in 160x144 has nothing out there, so the screen fills the surround with that
screen's own field, taken from the picture it drew.

Everything the cartridge laid out stays put. Text boxes, menus and the start menu
go inside a 160x144 rectangle centred in the surface and clipped to it, so a mod
reading `set_text_box_rect` reads the numbers it always did.

| Read | Value |
|---|---|
| `Gen2Screen.expanded` | Whether this screen grew to its control |
| `Gen2Screen.view_size() -> Vector2i` | The drawn surface in hardware pixels |
| `Gen2Screen.view_size_changed(size)` | Emitted when it changes |
| `Gen2Screen.interface_layer() -> Control` | The 160x144 rectangle, in surface pixels |
| `Gen2Screen.interface_masked` | Whether the screen is painting the surround itself |
| `Gen2Screen.screen_rect() -> Rect2i` | The 160x144 screen in native-layer pixels |

`set_native_size` may be the whole control, which is not a whole multiple of
160x144. A renderer that sized itself to what it was handed needs no change.

`set_screen_rect` turns a hardware-pixel number into a place on the surface. A
hardware pixel `p` lands at `rect.position + p * rect.size / Vector2i(160, 144)`.

A native-layer renderer keeps the zoom keys. `+`, `-`, `0` and the wheel step
`Gen2Screen.zoom_step`, which counts screen pixels per *hardware* pixel. A view
that answered `uses_hardware_viewport()` false has no hardware pixel, so those
events reach `handle_world_input` and a mod's registered actions instead.
`Gen2Options.zoom_step` persists the ladder position.

The surround is not painted over the native layer. When a screen laid out in
160x144 takes the picture (the pack, party, PC, dex, trainer card, an evolution, a
hatch, the day-care, the slot machine, card flip, a battle, `DoBattleTransition`)
the surround becomes that screen's field. It is drawn inside the hardware
viewport, which composites over the native layer, so raising it would crop a view
that had filled the surface. `set_interface_masked(masked)` is how a renderer
closes its own surround instead. `mods/examples/voxel_preview` draws the four bands
around `set_screen_rect`'s rectangle.

A battle fills the window either way. `_BattleScene` is a 160x144 picture, so the
screen fills the surround with the arena's own field. A battle renderer on the
native layer already has the world the overworld was filling the window with, so
it fills the surface itself and the screen leaves it alone. The HUD does not move
either way.

## Choosing the view

Choosing a view is one choice. `Gen2ModHost.select_view(id)` takes a mod id, not a
surface, and applies to whichever renderer kinds that id registered. Registering a
world renderer and a battle renderer under one id says the two are one view of one
world. A mod registering only one keeps the built-in renderer on the other.
`gen2` selects both.

| Method | Value |
|---|---|
| `view_ids() -> Array[StringName]` | Every id that registered a renderer of either kind, `gen2` first, then load order |
| `view_label(id) -> String` | The label the registration gave |
| `view_surfaces(id) -> Dictionary` | `{world, battle}`, which of the two that id draws |
| `selected_view() -> StringName` | The chosen id, whether or not its mod is loaded |
| `select_view(id) -> Dictionary` | Chooses it, and persists the choice |
| `view_changed(id)` | Signal, emitted whenever the chosen id changes |

The choice is stored per installation in `user://mods_disabled.json` and resolved
every time a surface builds a renderer. A stored id whose mod is uninstalled or
switched off draws with the built-in renderer, is not refused, and starts drawing
again the moment the mod registers.

Every way of choosing reaches the same live screen: `select_view` announces the
change on `view_changed` and both screens rebuild on it, so the launcher's mod
page, the start menu's VIEW row and `V` are one path. A mod neither needs nor
should hold a screen; it may connect to the signal.

Players reach the view from three places: the mod's launcher page, the VIEW row at
the top of the start menu's MODS entry (present as soon as more than one view is
registered), and `V` where `Gen2DebugKeys` is enabled. A mod must not register a
view button of its own.

The switch is covered. Building a renderer can stall a whole frame, and nothing on
one thread can animate over its own freeze. `Gen2Screen.play_view_cover` closes
with `StartTrainerBattle_SpeckleToBlack`'s scatter on the renderer still running,
builds the new one while the screen is black, and opens with the same frames
backwards.

### Name lengths

The start menu is the hardware's twenty-cell screen, so a registered name is drawn
into a fixed budget and a longer one ends in the charmap's "…":

| Row | Cells | What is drawn |
|---|---|---|
| A mod's name in the MODS list | 17 | The manifest's `name` |
| A setting's `label`, and the VIEW row's | 17 | `register_option`'s `label` |
| A setting's value, and a view's label | 8 | The chosen rung's label, a button's `press_label`, or `view_label` |

The numbers are `Gen2StartMenuPage.OPTIONS_LABEL_CELLS` and
`OPTIONS_VALUE_CELLS`. The built-in view is labelled "GBC 2D" to fit. The launcher
draws the full name either way.

## Replacing the battle renderer

`Gen2BattleScreen` owns the battle, the events and the text box. It decides
nothing about how a Pokemon, a panel or a bar is drawn. A registered battle
renderer is a `Node` providing:

| Method | Called when |
|---|---|
| `set_battle_data(data) -> bool` | The screen is ready, before the first view. False leaves the screen not ready |
| `set_view(view: Dictionary)` | The screen has new display values to show |
| `refresh()` | The renderer should redraw its current view |

Registration uses the same refusal rules as a world renderer, and shares both
optional methods (`uses_hardware_viewport()`, `set_native_size()`), the view
selection above, and the `V` cycle.

`view` carries plain values read out of a resolved battle event, never the battle
engine itself:

| Group | Fields |
|---|---|
| Who is standing | `enemy_species`, `player_species`, `enemy_name`, `player_name`, `enemy_level`, `player_level`, `enemy_shiny`, `player_shiny`, `enemy_unown_form`, `player_unown_form`, `enemy_substitute`, `player_substitute` |
| The fight | `battle_kind` (`wild` or `trainer`), `trainer_class`, `trainer_index`, `trainer_name` |
| Bars | `enemy_hp`, `enemy_max_hp`, `player_hp`, `player_max_hp`, `exp_pixels` |
| HUD | `hud_visible`, `enemy_hud_visible`, `player_hud_visible`, `trainer_hud_balls`, `trainer_hud_border` |
| Entrance | `battlers`, `intro_sprites`, `grayscale`, `enemy_trainer_pic`, `player_backpic`, `player_backpic_palette` |
| Hardware | `raster_scx`, `raster_scy`, `bg_map`, `bg_vbank1`, `bg_palette_maps`, `ob_palette_maps`, `anim_sprites`, `anim_tiles` |

Notes on the less obvious ones:

- A wild battle carries class 0, index 0 and an empty name. `trainer_class` is
  what `GameData.trainer_pic()` and `trainer_name()` take; `trainer_name` is the
  trainer's own name from the party record, not the class name.
- `exp_pixels` is a count out of 64, `PlaceExpBar`'s own unit, never a ratio.
- `enemy_unown_form` and `player_unown_form` are one-based letters for Unown and 0
  otherwise. Non-zero means `GameData.unown_pic(form - 1, back)` in place of
  `species_pic(number, back)`.
- The two HP values and `exp_pixels` are the *drawn* values, not the committed
  ones: a hit drains the bar over roughly a second and `set_view` is called on
  every step. A renderer wanting a moving bar needs no work; one wanting the final
  number should wait for the animation to end.
- `anim_sprites` is `wShadowOAM` as the animation left it, up to forty
  `{y, x, tile, attributes}` entries with the hardware's byte values: OAM
  subtracts sixteen and eight, so a `y` or `x` of zero is off screen.
- `anim_tiles` says where each tile of the animation window came from, as
  `{gfx, tile}` counted from `Gen2BattleAnimObject.BASE_TILE`. An OAM tile id below
  that base is not an animation tile.
- `hud_visible` is false for the length of a move animation
  (`BattleAnimClearHud` / `BattleAnimRestoreHuds`).
- `grayscale` is true for the entrance slide, since `GetSGBLayout
  SCGB_BATTLE_COLORS` runs only once `BattleIntroSlidingPics` returns.
- `intro_sprites` is the eighteen `{tile, x, y}` of the player's head and
  shoulders during the slide, empty outside it.

A renderer that ignores the hardware group draws a battle with no animation in it.

### The battlers

A fight does not open with two Pokemon standing on the field. Two trainers slide
in from opposite sides, the opponent sends out first, the player's back pic walks
off, and a ball puts a Pokemon where each trainer stood. Everything that happens
to a battler after that (a faint sinking the picture, a Fly or Dig user blanked
for a turn, a recall, a send-out, and every deformation from Tackle to Vibrate) is
a background-plane effect on the cartridge.

A renderer with no background plane has none of that, so `battlers` states it
plainly, one entry per side, on every frame:

```gdscript
view["battlers"] = {
    "player": {
        "kind": &"trainer",              # or &"mon", or &"none"
        "backpic": "kris",               # "" unless kind is trainer
        "trainer_class": 0,              # always 0 on the player's side
        "species": 0,                    # 0 unless kind is mon
        "visible": true,                 # false while the picture is off the square
        "offset_pixels": Vector2(142.0, 0.0),
        "scale": Vector2.ONE,            # the resize script's steps otherwise
    },
    "enemy": { ... the same seven, with trainer_class carrying the class },
}
```

- `kind` is what the square holds. `&"none"` is the stretch between the trainer
  walking off and the ball arriving. `backpic` feeds
  `GameData.player_backpic(kind)` and `player_palette(kind)`, `trainer_class`
  feeds `trainer_pic()` and `trainer_palette()`, `species` feeds `species_pic()`.
  A wild opponent is never a trainer and slides in as its own front pic.
- `visible` is whether the picture is on the square at all
  (`BattleBGEffect_HideMon`, `..._RemoveMon`). Not the same question as `kind`:
  `&"none"` is a square nobody stands on, `visible` false a picture taken away
  from one somebody does.
- `offset_pixels` is how far the picture stands from its resting square. Zero is
  standing still. The player comes in from the right and leaves left, the opponent
  the other way, and a faint is positive downwards. The whole-screen scroll is not
  in it; `raster_scx` and `raster_scy` already carry that. For WaveDeformMon and
  Psychic, which stretch rather than move, it is the mean of the window.
- `scale` is the side of the square `BattleBGEffect_RunPicResizeScript` last placed
  over the side of the whole picture, so a recall's shrink and a send-out's grow
  are one number. `Vector2.ONE` is every frame outside a resize. The cartridge
  subsamples rather than scales, so a renderer drawing a real scaled picture draws
  it better than the hardware did.

A renderer reading only `kind`, the three picture fields and `offset_pixels` draws
a correct battle.

### Where the battle is

A battle renderer has two optional methods of its own:

| Method | Effect |
|---|---|
| `set_world_context(context: Gen2BattleWorldContext)` | Where the battle is fought. Once per battle, after `set_battle_data` and before the first view |
| `handle_battle_input(event: InputEvent) -> bool` | Every input event the battle screen did not use. True consumes it |

`handle_battle_input` follows `handle_world_input`'s rule: the screen claims what
it needs and offers the rest. A `Gen2Button` is routed to whatever owns the screen
first, so the text box, the forget-move list, the pack rows and ball selection each
take their press and what arrives here is pointer and stick motion. Those three
also withhold everything else while up. A draining bar, the opening slide and a
move animation do not, since none reads input.

`view` says what is on the field and nothing about the place.
`Gen2BattleWorldContext` is the place: `map_id` (group and number), `tileset`,
`player_cell`, `player_facing` and `time_of_day`, the last being the row the world
was *drawn* with, so a battle entered from an unlit cave is staged in the dark.

It is a copy taken when the battle starts, not a handle: a renderer cannot reach
live world state through it. The map and tileset are numbers for
`GameData.world_map()` and `world_tileset()`. A battle started outside the world,
which is every development driver, supplies none and the method is not called.

## Experience for a capture

`register_catch_experience(manifest, provider)` makes a successful wild capture
award the caught Pokemon's experience. `PokeBallEffect` awards none, so this adds
rather than corrects, and it is off until a provider says otherwise:

```gdscript
class Policy:
	func awards_catch_experience() -> bool:
		return enabled
```

Registered with the manifest `register()` was handed, because the run is what the
policy belongs to. It is read on every throw, so switching a setting off mid-run
takes effect from the next one.

The award is the engine's own `_give_experience_for`, the same pass a faint takes,
so participants, Exp. Share splitting, stat experience, level ups, move offers,
happiness, evolution eligibility and the EXP-bar events are one implementation.
The opponent is not pretended to have fainted. Everything is spent between the
Gotcha line and the nickname prompt.

The catching tutorial and a Bug Contest catch are excluded.

## Annotating the battle

`register_battle_info(id, provider)` draws read-only annotations on the hardware
interface, over whichever battle renderer is selected. A provider receives a plain
snapshot and answers placements on the cartridge's 20x18 tile grid:

```gdscript
class Info:
	func annotate_battle(snapshot: Dictionary) -> Array:
		var out: Array = []
		if String(snapshot["menu_stage"]) != "move" or not snapshot["enemy_seen_before"]:
			return out
		for index: int in (snapshot["move_rows"] as Array).size():
			var row: Dictionary = snapshot["move_rows"][index]
			var mark: Array = _mark(int(row["effectiveness"]), int(snapshot["neutral"]))
			if mark.is_empty():
				continue
			var at: Vector2i = (snapshot["move_rows_at"] as Vector2i) \
				+ (snapshot["move_rows_step"] as Vector2i) * index
			out.append({
				"tile": mark, "at": Vector2i(int(snapshot["move_rows_right"]), at.y),
			})
		return out
```

A placement is `{"at": Vector2i}` plus one of:

| Key | What it is |
|---|---|
| `text` | Written with the interface's own font, cut at the right edge |
| `tile` | One 8x8 cell: eight bytes of 1bpp, or sixty-four palette indices |

and one optional flag:

| Key | What it is |
|---|---|
| `field` | `true` asks for the cartridge's interface field behind exactly the cells this placement occupies |

A placement outside the grid, or whose text does not fit, is refused rather than
clipped, and the refusal reaches `Gen2ModHost.failures()` with the mod's id and
why. It is recorded once per distinct refusal, not once a frame. Two providers
claiming one cell is refused rather than resolved by load order.

The interface font is the cartridge's, which is what `tile` is for: there is no
`+` in the charmap and `-` is the only sign a string can print, so a stage summary
reads `ATK2`/`SPD-1` and a super-effective, resisted or immune mark is supplied as
a tile. The example mod's three are a circle with a centre dot, a triangle and an
X.

Use `field` where ink would sit on bare battle scenery: a stage figure at the top
of the screen or a weather glyph beside the enemy. A mark on the move list or over
the command panel already has a field and should not set it. The host draws the
field just below the annotations, at the opacity the selected renderer asks its
interface to be drawn at.

The snapshot carries what a subscriber of past events cannot know:

| Key | |
|---|---|
| `player_stages`, `enemy_stages` | `Gen2BattleMon.stages`, live |
| `player_species`, `enemy_species`, `player_level`, `enemy_level` | Who is standing |
| `enemy_types`, `enemy_identified` | The defender, and whether Foresight named it |
| `enemy_seen_before` | Whether this save had seen the opponent before this battle |
| `weather`, `weather_turns` | What is on and how much is left |
| `hud_visible`, `enemy_hud_visible`, `player_hud_visible`, `menu_stage`, `menu_position`, `move_cursor` | What is on screen |
| `move_rows` | The move list, each row with its exact `effectiveness` |
| `move_rows_at`, `move_rows_step`, `move_rows_right` | Where `MoveSelectionScreen` puts its rows |
| `neutral` | What `effectiveness` compares against |

`effectiveness` is `GameData.type_effectiveness` over the defender's types with
Foresight applied, so a mod never copies the type chart.

The layer is refreshed after every event, view push and menu change, and hidden
from the frame a modal takes the interface: the party page, the pack and its
sub-lists, ball selection, the forget offer, the naming prompt and the entrance.

## World state and mod pose

The game stays logically grid-based. The player and NPCs occupy walk cells,
movement commits one cell at a time in four cardinal directions, and interactions
use the current logical cell plus one cardinal facing. Animating a sprite between
cells does not change that.

A movement mod may add a more precise pose for smooth, analog, first-person or 3D
movement, with a sub-cell position and an arbitrary facing angle. It is an extra
layer, not a replacement. The core world stays responsible for collision, cell
transitions, map triggers, warps and interactions, and a mod must not overwrite the
authoritative cell or bypass those boundaries.

When a mod requests an interaction it projects its pose back onto the normal rules:
resolve a deterministic logical cell, quantize the facing angle to one of the four
source directions using the source tie-breaking, and pass both to the existing
interaction path.

## Putting one sprite in the world

A mod that wants a follower, a pet, a marker over an object or a ghost of a
previous run registers a world **actor**, and the built-in view draws it with the
map's own objects.

```gdscript
func register(host: Gen2ModHost, manifest: Gen2ModManifest) -> void:
    host.register_world_actor(manifest.id, Follower.new())
```

An actor is a `RefCounted` and never a `Node`, because it is a pose and not a view.
Three methods, refused by name at registration:

| Method | Called when |
|---|---|
| `set_world(world: Gen2WorldAPI)` | The map changed, or the view was created |
| `advance_frame()` | Once per world frame, after the player's step advanced |
| `sprites() -> Array` | What to draw now. Asked once a frame however many times the screen redraws |

Two more are optional and offered only to an actor that defines them:

| Method | Called when |
|---|---|
| `interact(cell: Vector2i, facing: int) -> bool` | A press of A that no cartridge object, background event or tile branch answered. The first actor answering true consumes the press |
| `take_requests() -> Array` | The actor's one-shot outbox, drained once a world frame and emptied by the drain |

`interact` is offered only after `Gen2WorldAPI.interact()` answered nothing, so a
mod can never shadow a cartridge interaction. Only the actor's pose changes, so no
player event is spent.

`take_requests` is where an edge goes; `sprites()` is where a pose goes. The one
request kind is `{"kind": &"cry", "species": n}`, played through the same player a
script's `cry` command uses. A mod may not play a sound, so it asks and the host
spends it. Anything else in the outbox is dropped.

Each entry of `sprites()` names cartridge art and nothing else:

| Key | Meaning |
|---|---|
| `icon` | An `IconPointers` row, as `GameData.mon_menu_icon(species)` answers it |
| `sprite` | An `OverworldSprites` row instead, for an NPC or object picture |
| `facing` | `Gen2WorldSprite.FACING_*`. Right is the left picture mirrored |
| `position_cells` | Where to draw it, in fractional walk cells |
| `colors` | Optional. Four colours instead of the map's sprite palette. What a visible encounter wears, so a shiny one is shiny before the battle starts |
| `emote` | Optional. `Gen2WorldActors.EMOTE_SHOCK` through `EMOTE_GRASS_RUSTLE`, drawn two rows above the sprite as `SpawnEmote` puts one over a map object. It is state, not an edge: up for as long as the entry keeps asking. An index outside the twelve is no emote |

The host resolves the strip, the palette, the time of day and the icon's two-frame
animation, so a mod never composes pixels. An entry naming art the cache does not
carry is dropped.

An actor's sprite is presentation. It occupies no cell, blocks nothing, nobody
talks to it, no trainer sees it and it is in no snapshot. Actors are sorted into
the object pass by the row they stand on, so a follower one cell below an NPC is
drawn over it.

A world renderer that wants to draw them takes the optional
`set_actors(actors: Gen2WorldActors)`, handed the same resolved list.

### The map fades

A warp spends `MapSetupScript_Door`'s two fades, sixteen frames in which no input
is read. A renderer is offered each step through the optional
`set_fade(order: int, white_fill: bool)`: `order` is the palette order
`DmgToCgbTimePals` applies to every palette on screen, and `white_fill` is
`FillWhiteBGColor`, which only the way out runs. The identity order
(`Gen2WorldPalette.FADE_IDENTITY`) is every other frame of the game. A renderer
that does not define it cuts to the new map on the whitest frame; the host spends
the frames either way.

## Visible wild encounters

A mod that wants wild Pokemon standing on the map instead of a roll on every step
registers a provider. It owns the population and nothing else; every rule a
cartridge owns stays in `Gen2WorldAPI`.

```gdscript
func register(host: Gen2ModHost, manifest: Gen2ModManifest) -> void:
    host.register_visible_encounters(manifest.id, Roamers.new())
```

A `RefCounted` and never a `Node`, with four methods refused by name at
registration:

| Method | Called when |
|---|---|
| `set_context(context: Dictionary)` | The map changed, and whenever the player's pose, the occupancy or the tables move |
| `advance_frame()` | Once per hardware frame the overworld is running. Not while a battle, a menu, an overlay, a text box, a map fade or a trainer's approach owns the world, which is when the map's own objects stand still too. A provider counting its own calls is counting the time the player spent walking around |
| `encounters() -> Array` | The population now. Asked once a frame |
| `battle_finished(id: StringName, result: Dictionary)` | A battle this provider's entry started ended |

The context is a snapshot, never a live handle:

| Key | Meaning |
|---|---|
| `map` | `Vector2i(group, number)` |
| `eligible` | `{grass, surf}` to `PackedVector2Array` of cells a wild may stand on. `CanEncounterWildMon` per cell. Taken again, and pushed, if a script runs `wildoff` or `wildon` while the map is up |
| `occupied` | The walk cells the map's own objects hold this frame: NPCs, item balls, all four cells of a big object, and both cells of one mid-step. Refreshed with `player`, not with `map`. An entry outside `eligible` is dropped, so the two are deliberately separate. Refusing an occupied cell is the provider's choice. The player's cell is not in it |
| `tables` | `{grass, surf}` to `{source, slots}`, the table a roll would read now, with swarm and Bug Contest substitutions and the time of day already applied. A slot is `{species, min_level, max_level}`. Refreshed while the map is up, whenever the hour, a swarm or the Bug Contest moves what a roll would read |
| `player` | `{cell, facing}` |
| `run_seed` | The run's seed, so a population is reproducible |
| `generation` | Bumped on every map change; an older one means the context is stale |

Each entry of `encounters()`:

| Key | Meaning |
|---|---|
| `id` | Stable across frames. What a battle result is reported under |
| `cell` | Must be in `eligible`. Which method it is in decides which table it is checked against |
| `facing` | `Gen2WorldSprite.FACING_*` |
| `species`, `level` | Must be offered by that table |
| `dvs` | The packed DV word, carried into the battle unchanged |
| `pulse` | Optional. Ask for the shiny sparkle over this entry |
| `glow` | Optional `{color: Color, amount: float}`. Walks the Pokemon's colours toward `color` by `amount`, leaving colour 0 alone. Presentation only |

Anything else is dropped, including an entry naming `shiny`: shininess is
`CheckShininess` over the DVs and is the host's answer. A malformed `glow` costs
the glow rather than the entry. At most `Gen2WorldEncounters.MAX_ENTRIES` entries
are drawn in a frame.

`amount` is rounded onto `Gen2WorldEncounters.GLOW_RUNGS` steps, so nine values
are all a mod can reach. Both world renderers cache one sprite texture per distinct
set of four colours and neither evicts, so a smoothly interpolated glow would leak
a texture every frame. Send whatever cycle you like; the nearest rung is what
reaches the palette.

What the host does with a valid population:

- Draws it through the actor layer with the species' own four colours, shiny or
  not and glowing or not, so a renderer reading `set_actors` gets it for free.
- Turns the ordinary post-step roll off while any provider is registered.
  Scripted, fishing, Headbutt, Rock Smash, Sweet Scent and Bug Contest encounters
  keep their own paths.
- Starts the normal wild battle when the player steps onto an entry, with that
  entry's exact species, level and DVs, then calls `battle_finished`. Whether the
  entry survives is the provider's rule to document.
- Keeps an entry it already admitted while it keeps standing on the same cell's
  method with the same species and level, even after the tables move under it. A
  route entered in daylight therefore turns over to its night species as each
  wild is replaced, rather than emptying at six. A new entry is checked against
  the tables in force now, so `generation` never moves for an hour boundary.
- Discards the population, its sprites and any running pulse on a map change.
- Plays `ANIM_SEND_OUT_MON` with the shiny param over a pulsing shiny entry, sound
  included. A request inside `Gen2WorldEncounters.PULSE_FRAMES` of the last one is
  dropped, so a provider may ask on spawn and every ten seconds. A pulse on an
  ordinary Pokemon draws nothing.

A world renderer that wants to draw the sparkle itself takes the optional
`set_encounters(encounters: Gen2WorldEncounters)`.

### The earthquake

`Gen2WorldEffects.offset()` is `StepFunction_ScreenShake`, in hardware pixels and
positive downward. It reaches hSCY alone, so it is the *background's* offset and
moves no sprite. A renderer taking `set_effects` applies it to the camera the map
is placed at, or ignores it and does not shake.

## Hidden items

A mod that wants a follower or a detector to pick up a hidden item reads them and
**asks** for one. It never takes one: taking one writes the bag, the event flag and
the save, and runs `hiddenitem`'s own `verbosegiveitem` with its FOUND text,
fanfare and pack-full branch.

`Gen2WorldAPI.hidden_items()` is the read: one entry per `BGEVENT_ITEM` on the
current map, taken or not. Scene-free, so a probe can walk a map with no game
running.

| Key | Meaning |
|---|---|
| `cell` | Where the record sits |
| `item` | The item it gives, with the catalog's patch applied |
| `flag` | Its event flag, which is the site's completion |
| `taken` | `event_flag_active(flag)`. The Itemfinder's own test |

`Gen2ModHost.request_hidden_item(cell)` is the ask. The mod names a cell and reads
nothing back. The host validates it against that list and, on the next free world
frame, runs the map's own script through the ordinary path, so the text box, the
fanfare and the pacing are the world screen's.

- An ask for a cell with no record, or whose flag is set, does nothing.
- An ask for a cell already queued is dropped, so a provider may read
  `hidden_items()` every frame and name what it stands on without tracking its own
  asks. The pack-full branch leaves the flag clear, so asking again later works.
- One is spent per frame; the rest wait in order.
- An ask made inside a battle, a text box, a warp or an overlay is spent when the
  world can spend it rather than dropped.

## Asking the host for an item

`Gen2ModHost.request_item_gift(item, quantity)` is the twin for an item no map
gives. The mod names an item and reads nothing back; on the next free world frame
the host runs `verbosegiveitem`'s transaction: the bag write, the fanfare, the
received line, the pocket line and the pack-full branch. The queue behaves exactly
as a hidden item's. An unknown item number does nothing.

Use it where the mod can see the moment but the script has no give site:
`special Diploma` reaches the world channel as a `diploma_requested` runtime
request, and the script is `writetext`, `special Diploma`, `setevent` with nothing
to patch. `patch_check` changes the number an existing site hands out; this is for
when there is no site.

## Asking the battle to say a line

`Gen2ModHost.request_battle_message(id, text)` prints one line in the battle's own
box, with its own pacing and its own press, after the line being shown when the
request was made. Asked for from a `caught` handler it lands between `Gotcha!` and
the nickname prompt.

- Queued and spent in request order, the way the two asks above are.
- Dropped where no battle is showing lines, rather than held: a line about a
  moment that has passed is worse than none. What a battle left queued goes with
  it.
- One line of the cartridge's own font, 18 tiles. A longer line, or one carrying a
  newline, is refused rather than clipped, and the refusal reaches
  `Gen2ModHost.failures()` under the mod's id.

It returns `{ok: true}` or a refusal, so a mod may say why nothing was printed.
`register_event_mutator` rewrites an existing line instead; there is one mutator
per channel, so adding a line does not cost a mod that seam.

## Reading the bag

`Gen2ModHost.inventory()` answers the live world's `{item: quantity}`, and `{}`
when no world is open. Read only, and a copy.

It is one narrow accessor rather than a handle on `Gen2WorldAPI`, because a
non-renderer mod is deliberately given no world.

## Reading the run's progress

`Gen2ModHost.progress()` answers what the run being played has achieved, and `{}`
when no world is open. `Gen2ModHost.progress_for(save)` answers the same off a
save, which is what a `save_activated` callback has: the slot has been chosen and
no world exists yet. Both are copies, and read only.

Every field is a state the run has **reached** rather than a moment it passed, so
a mod installed onto a save already played reads what that save has. That is the
difference between "eight badges" and "a badge was awarded": the first is still
readable and the second is gone.

| Key | Meaning |
|---|---|
| `badges` | A sixteen-bit mask, bit `i` being badge `i` in badge order. Crystal's order whichever cartridge is open, so nothing reads the Gold and Silver flag table |
| `badge_count` | The same mask popcounted, which is `_GetVarAction`'s `.CountBadges` |
| `hall_of_fame` | `STATUSFLAGS_HALL_OF_FAME_F` |
| `beat_red` | `wSpawnAfterChampion` is `SPAWN_AFTER_RED` |
| `seen_count`, `caught_count` | The dex counters |
| `unown_caught` | How many Unown forms have been caught |
| `party_count`, `kept_count` | The party, and the party plus the boxes |
| `highest_level` | The highest level anywhere in either |
| `shiny_count` | How many of those are shiny |
| `money`, `coins` | The wallet and the Game Corner |
| `step_count`, `phone_contacts` | The step counter and the registered numbers |
| `play_hours`, `play_minutes` | The play timer the trainer card prints |

**An absent field stays absent rather than becoming a zero**, so a mod written
against a later host reads a missing answer as nothing achieved rather than as an
achievement lost. A save with no world at all answers the save's own half and
leaves the world's out.

`signal progress_changed(progress)` is emitted at most once a world pass, and only
where a field actually moved. Nothing is read at all while nothing is connected:
walking the party and every box is the expensive half of a reading.

```gdscript
host.progress_changed.connect(func(progress: Dictionary) -> void:
	var mask: int = int(progress.get(&"badges", 0))
	...
)
```

The first reading of a run is the save being opened rather than anything
happening in it. A mod that announces changes adopts that one silently and
compares against it afterwards.

## A notice over the map

`Gen2ModHost.request_notice(id, notice)` asks the world screen to raise a banner
over the overworld: an icon, a title, a line and a sound. It is a **request** and
never the act, the way `request_hidden_item` is.

```gdscript
host.request_notice(manifest.id, {
	"title": "BADGE WON",
	"line": "ZEPHYRBADGE",
	"icon": {"badge": 0},
	"sound": &"get_badge",
})
```

It is drawn as `PlaceMapNameSign` draws the landmark banner, which is the only
thing the cartridge ever puts over a live map. Gold and Silver ship neither that
routine nor its sheet, so those two get the ordinary text-box frame instead.

- Queued and spent the way a hidden item's ask is: held rather than dropped while
  a battle, a menu, an overlay, a text box, a warp or a script owns the world, one
  per free world frame, and never over a banner already up.
- `title` and `line` are each one line of the cartridge's own font and are
  **refused rather than clipped** past `Gen2MapNameSignPage.NOTICE_COLUMNS`.
- At most `Gen2ModHost.MAX_NOTICES` may wait; past that the ask is refused by name
  and the refusal reaches `Gen2ModHost.failures()`.
- The answer is `{ok: true}` or a refusal with a reason, so a mod can say why
  nothing was drawn.

`icon` is the vocabulary an actor's `sprites()` and a battle annotation's `tile`
already share, so a mod never composes pixels:

| Key | Drawn from |
|---|---|
| `{"badge": 0..7}` | The trainer card's own badge art, which is the only place the game draws a badge. The Kanto eight reuse the Johto pictures on the cartridge and have none of their own |
| `{"species": n}` | The party menu's icon for that species |
| `{"sprite": n}` | An `OverworldSprites` row, facing down |
| `{"tile": indices}` | A raw 16x16 of palette indices, drawn in the banner's own palette |

`sound` is a name out of the small set the host owns, so a mod never names a raw
effect number: `item` (the default, the jingle a hidden item plays), `key_item`,
`get_badge`, `transaction` and `none`.

**`SFX_SHINE` is deliberately not among them.** The sparkle means a shiny Pokémon
and nothing else, and a mod firing it for something ordinary teaches a player to
distrust it.

## A page of your own

`Gen2ModHost.register_page(id, {"title": String, "rows": Callable})` gives a mod
one screen. `rows` answers an Array of `{label, detail, icon, locked}`, asked
fresh when the page is drawn rather than when it is registered, so a page is a
view of state the mod holds.

```gdscript
host.register_page(manifest.id, {"title": "BADGES", "rows": _badge_rows})
host.register_menu_entry(Gen2ModHost.MENU_START, &"my_badges", {
	"label": "BADGES",
	"action": Gen2ModHost.START_ACTION_OPEN_MOD_PAGE,
	"page": manifest.id,
})
```

The host draws it with the screen's own font and frame, so the page needs no
node, no renderer and no art of its own; `icon` is `request_notice`'s vocabulary.
A locked row is drawn the way the Pokédex draws an unseen entry.

- One page per mod, refused by name for a second, the way a stats page is.
- `page` on the menu entry names which page the row opens, and defaults to the
  row's own id. A row naming `START_ACTION_OPEN_MOD_PAGE` with no page behind it
  is **absent** from the start menu rather than present and dead.
- A row with no `label` is dropped, an `icon` that is not a set of fields is no
  icon, and an answer that is not an Array is no rows.
- The d-pad scrolls the list and B leaves, the way the trainer card is paged.

## Shiny rolls

Every wild the game builds rolls its own DVs off the battle's generator, the way
`LoadEnemyMon` does. `register_shiny_rolls(id, provider)` says how many words one
wild is drawn with, which is the later games' charm:

```gdscript
class Held:
	func shiny_rolls(context: Dictionary) -> int:
		return 3 if int(Gen2ModHost.instance().inventory().get(SHINY_CHARM, 0)) > 0 else 1
```

The host draws up to that many, keeps the first that `Gen2Stats.is_shiny` accepts
and otherwise the last, and clamps to `Gen2ModHost.MAX_SHINY_ROLLS`. 0 and 1 both
mean the cartridge's single roll.

| `context` key | Meaning |
|---|---|
| `species` | What is about to be built |
| `level` | Its level, already chosen |
| `method` | The encounter method, empty where there is none |
| `map_group`, `map_number` | Where, or -1 apiece |

It carries no bag; `inventory()` is the live one.

Three wilds keep their own answer and no provider is asked: one whose request
already carries `dvs` (the Pokemon a visible encounter's player walked up to),
`BATTLETYPE_FORCESHINY` (the red Gyarados), and a roaming Pokemon, which keeps its
stored word. A wild UNOWN rerolls until its letter is one the Ruins of Alph puzzle
has unlocked.

Providers compose additively rather than by registration order: the total is the
cartridge's own roll plus the sum of what each provider adds past it.

    rolls = 1 + sum over providers of max(0, provider answer - 1)

A provider answers the total it would give alone, so one provider on its own is
unchanged and a mod written against an older host still reads right. Two mods
worth 3 and 12 rolls give 14, not 12.

## An alternate field-move source

`register_field_move_source(id, provider)` says an HM's field move may be used
without a party member who knows it. The provider is read only:

```gdscript
class Anywhere:
	func allows_field_move(move: int) -> bool:
		return true
```

The host owns everything else:

| Question | Where the host answers it |
|---|---|
| Which item teaches which move | `GetTMHMItemMove` |
| Whether it is in the bag | The live world's items |
| Whether the badge is in hand | Each `Try*OW`'s own `CheckBadge` |
| Whether the tile allows it | The staged request the party submenu reaches |
| What the move then does | The same commit, animation and script |

The party is asked first, so a game with no provider resolves every field move
exactly as before, and a Pokemon that knows the move keeps its submenu row. Only
the seven HM moves have an alternate source: CUT, FLY, SURF, STRENGTH, FLASH,
WHIRLPOOL and WATERFALL. Rock Smash is a TM.

The source is carried through every entrance: the party submenu, `Gen2WorldAPI`'s
staged request and complete pairs, the A-button prompts at a tree, water, a
whirlpool and a waterfall, the Strength boulder script, Flash, and Fly's region
map. A move with no Pokemon behind it prints `<PLAYER> used CUT!` and surfs on the
ordinary sprite.

FLY and FLASH are chosen from no tile and no party member, so the start menu grows
a **MOVES** row: one entry per HM move the bag can supply, the party does not know
and the badge allows. It is absent when that list is empty.

## Renewing a Repel

`register_repel_renewal(id, provider)` is offered the step an active Repel runs out
on, before the encounter roll:

```gdscript
class Weakest:
	func repel_to_use(inventory: Dictionary) -> int:
		for item: int in [ITEM_REPEL, ITEM_SUPER_REPEL, ITEM_MAX_REPEL]:
			if int(inventory.get(item, 0)) > 0:
				return item
		return 0
```

`inventory` is a copy of the bag. Answering an item number puts the cartridge's
YES/NO box over the map; YES runs the pack's own field item transaction, so exactly
one item is spent and its step count applied. Answering 0 changes nothing.

The question is the step's own player event, so no wild is rolled underneath it. An
offer landing on a step a script, warp, overlay or battle owns waits for a step
that can spend it.

## What a renderer mod needs

[DramaticShapeVoxelMod](https://github.com/DramaticShape/DramaticShapeVoxelMod) is
the reference for what a renderer mod has to be able to do: a voxel diorama with
selectable camera pitch, first and third person, VR, reflections and a day cycle,
shipping no cartridge art. Everything it needs is in the contract above.

Movement is the part worth naming. `Gen2WorldAPI.player_step_offset_cells()` and
`Gen2WorldObject.step_offset_cells()` return an in-flight step as a fractional
cell, from one cell behind the committed cell down to zero. The logical cell
commits at the start of the step; the fraction is presentation only and never
reaches collision, events or the snapshot.

`applymovement` applies its whole stream at once, so a scripted path commits
together and the offset trails by as many cells as are left to draw;
`advance_scripted_steps_pass()` drains that trail, 16 overworld passes a step for
the slow commands, 8 for plain, 4 for bike speed. A pass is two hardware frames
(`Gen2WorldAPI.FRAMES_PER_OVERWORLD_PASS`, `MaxOverworldDelay`).
`Gen2WorldObject.frame` is the cartridge's `Facings` index, 0 to 3, changing every
four passes.

A hop is the one step with a second axis.
`Gen2WorldAPI.player_height_offset_pixels()` and
`Gen2WorldObject.height_offset_pixels()` return how far above the ground the sprite
is drawn, in world pixels and positive upward, which is `UpdateJumpPosition`'s
`.y_offsets` table over the step's frames. It is zero at rest, on every ordinary
step, and on the frame the hop completes. Only a ledge hop and the three
`jump_step` commands raise it, each covering two cells. Presentation only: the
cell, the collision, the triggers and the snapshot are at the landing cell for the
whole arc.

Not covered: the teleport, skyfall and dig step types. `teleport_from`,
`teleport_to`, `skyfall` and `step_dig` reach the caller as a
`movement_command_requested` event and change nothing. None moves a cell on the
cartridge either, so each is a pose a renderer has to be told about rather than an
offset it can read.

Per-block height is deliberately not a host boundary. A renderer resolves shape
from the collision permissions, the block grid and the tileset, all already public.

## Adding a menu entry

`register_menu_entry(menu, id, entry)` appends to a menu the game builds. The
cartridge's own entries are never registered, so a mod can add but not reorder or
remove them.

| Menu | Where the entry lands | `entry` keys |
|---|---|---|
| `Gen2ModHost.MENU_START` | The start menu, immediately before EXIT | `label`, optional `handler: Callable` |
| `Gen2ModHost.MENU_PACK_POCKET` | After the pack's four source pockets | `label`, `pocket` |
| `Gen2ModHost.MENU_MART` | After a mart's cartridge shelf | `label`, `item`, optional `price`, optional `available(mart)` |

```gdscript
host.register_menu_entry(Gen2ModHost.MENU_START, manifest.id, {
	"label": "Atlas",
	"handler": func() -> void: print("opened"),
})
```

A start-menu entry may name a host **action** instead of a handler, for a row whose
work is opening a screen a mod never receives:

```gdscript
host.register_menu_entry(Gen2ModHost.MENU_START, manifest.id, {
	"label": "PC",
	"action": Gen2ModHost.START_ACTION_OPEN_BILLS_PC,
	"visible": func(context: Dictionary) -> bool: return enabled,
})
```

`Gen2ModHost.START_ACTIONS` is the allow list. `OPEN_BILLS_PC` opens BILL'S PC at
the same top menu the Pokemon Center's machine reaches. An optional
`visible(context)` predicate is asked with a copy of
`{party_count, pokedex, pokegear}` and leaves the row *absent* rather than present
and refused. The host applies its own gate after the predicate, so a row cannot be
shown where the game would refuse it: `OPEN_BILLS_PC` needs a party.

The start menu shows eight rows at once and scrolls past that. A fully unlocked
save already fills those eight, so the MODS row and every registered row are
reached by scrolling: the window follows the cursor, and the cursor wraps at both
ends. The Bug Contest's list starts two rows lower and shows seven. A mod may
register any number of rows.

A start-menu entry with neither an action nor a handler still appears, marked
unavailable. A pocket's number must be at or above `Gen2ModHost.FIRST_MOD_POCKET`;
1 to 4 are the cartridge's ITEM, KEY_ITEM, BALL and TM_HM, and an item joins the
pocket its own definition names. Two mods claiming one entry id is refused with
`duplicate_menu_entry`.

A mart filter receives the resolved mart dictionary, including `mart_id`,
`dialog_id` and `variant`. Its row is omitted when the filter answers false or the
source shelf already sells that item. Selection goes through the ordinary mart
transaction, including money, stack limits and save validation.

## Adding a row to a party member's menu

`register_party_member_menu(id, entry)` appends to the box a party slot opens. Both
halves are Callables taking the one-based slot, because a row here is about a
member rather than about the menu:

```gdscript
host.register_party_member_menu(manifest.id, {
	"label": func(slot: int) -> String:
		return "FOLLOWING" if slot == following_slot else "FOLLOW",
	"handler": func(slot: int) -> void:
		host.set_option(manifest.id, &"slot", slot),
})
```

Rows land after every cartridge action and before CANCEL. The list still stops at
the source's `NUM_MONMENU_ITEMS`. A label answering an empty string drops its own
row, which is how a row is shown conditionally. Choosing one calls the handler and
closes the menu.

Not offered for an egg, and not inside a battle, where the party list is a switch.

## Adding a page to the stats screen

`register_stats_page(id, {"build": Callable})` adds a page after the cartridge's
pink, green and blue. `build` takes the screen's snapshot and answers placements on
its own 20x18 tile grid; the host writes them with the screen's font, so the page
needs no node, renderer or art:

```gdscript
host.register_stats_page(manifest.id, {
	"build": func(page: Dictionary) -> Array:
		return [
			{"divider": 10},
			{"text": "DV", "at": Vector2i(7, 8)},
			{"text": str(Gen2Stats.attack_dv(int(page["dvs"]))), "at": Vector2i(7, 9)},
		],
})
```

| Placement | Draws |
|---|---|
| `{"text": String, "at": Vector2i}` | The string at that tile |
| `{"divider": int}` | The pink and blue pages' vertical divider down that column |

The lower half is rows 8 to 17 and a placement outside it is dropped, which keeps a
page off the upper half's name, level and front pic. The snapshot is
`Gen2MonStatsScreen.snapshot`, which carries `dvs` (the packed word, read with
`Gen2Stats.attack_dv` and friends) and `stat_exp` (keyed `hp`, `attack`, `defense`,
`speed`, `special`) beside everything the cartridge pages print.

Pages turn with LEFT and RIGHT and wrap, A on the last page leaves the screen, and
the 2x2 page indicators are centred against the right arrow. Five pages is the
ceiling (`Gen2StatsScreenPage.MAX_PAGES`); past it registration is refused with
`stats_pages_full`, and a second mod claiming one id with `duplicate_stats_page`.
An egg has no pages at all.

## Holding a run rather than an installation

A mod whose settings decide what a whole playthrough looks like has a problem
`read_save_data` alone does not solve: an installation option changed mid-run would
silently rewrite the save being played, and opening another save could not restore
the settings that made it. `register_save_lifecycle(manifest, provider)` is the
seam for that.

The `manifest` is the object `register()` was handed, and it *is* the capability:
the host keeps it beside the provider, so a callback reaches
`read_save_data`/`write_save_data` for its own namespace and no other mod's. A
manifest this host never discovered registers nothing.

| Method | Called when |
|---|---|
| `save_created(save)` | A save has just been made, before it is written. Snapshot whatever the run is built from |
| `save_activated(save)` | That save is about to be played. `save` is `null` for a development run |
| `save_deactivated()` | The save was closed |

Ordering:

1. The host drops every lifecycle mod's overlay contributions, in one pass.
2. `save_activated` runs, in registration order.

So a provider always starts from the cartridge, two slots cannot leak patches into
one another, and a provider that fails leaves nothing installed.

Save the compact *inputs* plus an algorithm version, not the generated plan: a plan
can exceed the 64 KiB namespace and duplicates cartridge rows anyway. A save
carrying no snapshot has no run and should stay vanilla.

Registered settings need none of that. The host snapshots them onto the save
(`Gen2SaveData.run_options`) when it is created, binds that snapshot while the slot
is played, and puts a mid-run change into the save rather than the installation. So
`host.option()` answers with what *this* run is played with, the launcher edits the
installation with no slot open, and a slot written before the snapshot existed
adopts the installation once, on first activation.

## Reading the run's rules

`world.rules` is a `Gen2Rules`: which of the cartridge's own bugs this run
reproduces, and which challenge it is played under (`Gen2Rules.CHALLENGES`:
`vanilla`, `hard` or `nuzlocke`). Read it, do not write it. A rule that changed
mid-run would make the save it produced unreproducible, and the challenge is
fixed when the save is created.

```gdscript
if world.rules.reproduces(&"metal_powder_overflow"):
	...
if world.rules.challenge == Gen2Rules.CHALLENGE_HARD:
	...
if world.rules.is_nuzlocke():
	...
```

`Gen2Rules.FLAGS` is every flag this build names, mapped to its default. Each is
named for the *hardware's* behaviour, so a flag that is on means the cartridge's
bug is reproduced and off means this project's corrected answer is used. An unknown
flag answers false rather than failing, so a mod written against a later build
still runs.

The same object is on a battle (`battle.rules`), and exactly one set is installed
at a time (`Gen2Rules.active()`), because the damage formula and the experience
curves are statics with no engine object to read it off.

## Adding a setting

`register_option(id, option)` describes one setting: a ladder of values, a number
in a range, or a button. The game and the launcher each build a surface from that
one registration, so a mod writes no settings screen.

```gdscript
host.register_option(manifest.id, {
	"key": "draw_distance", "label": "DISTANCE",
	"values": [8, 16, 24, 0], "labels": ["8", "16", "24", "FULL"],
	"default": 16,
})
```

| Key | Meaning |
|---|---|
| `key` | Addresses the setting within the mod |
| `label` | Shown to the player |
| `kind` | Optional. `Gen2ModHost.OPTION_LADDER` (default), `OPTION_NUMBER` or `OPTION_BUTTON` |
| `values` | The rungs, at least one. A toggle is a two-rung ladder. Ladder only |
| `labels` | Optional. What each rung is shown as, defaulting to the values |
| `minimum`, `maximum` | The range, inclusive. Number only |
| `step` | Optional. What one press moves the value by, default 1. Number only |
| `default` | Optional. The rung or number used until the player picks one |
| `press_label` | Optional. What a button's control reads, default `Go`. Button only |

A **number** setting is one whole value in a range: a randomizer's seed is one
field with ten thousand values, and dialling it as four one-digit ladders would
spend four menu rows. Set it with `set_option(id, key, value)`, clamped into the
range, or step it with `adjust_option(id, key, delta)`, which both surfaces call
and which steps a ladder just as well. The launcher draws it as a typed field; the
start menu steps it left and right.

A **button** setting is a press rather than a ladder, for something with no value
to keep. It stores nothing, `press_option(id, key)` is what both surfaces call, and
`option_changed` carries a null value.

Read it back with `host.option(id, key)`, or `option_index(id, key)` for the rung,
which is -1 for anything that is not a ladder. Connect to
`option_changed(id, key, value)` rather than polling. The host keeps the entry
object `register` was called on for as long as the mod is loaded, so connecting a
signal to it is safe and a mod does not have to hold itself in a static variable.

The two surfaces are a **MODS** entry in the start menu and rows on that mod's card
in the launcher. The entry appears only when at least one loaded mod registered a
setting.

A change is committed the moment it is made. With no slot open it lands in
`user://mod_options.json`, keyed by mod id: that file is the installation's values
and the template a new run is created from. While a slot is played the change
belongs to the slot (`run_options`). Only values are stored, never what a setting
means, so a mod that drops a rung in a later version finds its stored value refused
and its default used. Uninstalling a mod drops what it stored.

Per-slot state belongs in the save. A discovered manifest uses
`host.read_save_data(manifest, save)` and
`host.write_save_data(manifest, save, value)` for its own namespace. Both sides
deep-copy dictionaries, and writes larger than 64 KiB of UTF-8 JSON are refused.
The manifest object is the capability: constructing another manifest with the same
id grants nothing.

## Adding a control

`register_action(id, action)` declares a control of the mod's own. A mod cannot see
the cartridge's eight, and the screen claims every one of them before a renderer is
offered anything, so reading raw keycodes out of `handle_world_input` produces
controls that cannot be rebound, collide silently with the d-pad, and do not exist
on a touchscreen.

```gdscript
host.register_action(manifest.id, {
	"key": "pitch_up", "label": "Camera up",
	"default": [{"kind": "key", "code": KEY_F}],
})
```

| Key | Meaning |
|---|---|
| `key` | Addresses the control within the mod |
| `label` | Shown wherever the control is listed or drawn |
| `default` | Optional. Bindings in `Gen2InputActions`' own shape |

`default` takes the same three kinds the cartridge's eight take:

```gdscript
{"kind": "key",        "code": <physical keycode>}
{"kind": "pad_button", "code": <JoyButton>}
{"kind": "pad_axis",   "code": <JoyAxis>, "sign": -1 or 1}
```

A default already bound to one of the eight is dropped and reported, because it
would never fire. The action still registers, unbound on that slot, and the refusal
reaches `Gen2ModHost.failures()` and the launcher. `W`, `A`, `S` and `D` are the
d-pad's default keys.

Read one without an `InputEvent`:

| Call | For |
|---|---|
| `action_changed(id, key, pressed)` | The edge. A signal, like `option_changed` |
| `action_held(id, key) -> bool` | The poll a camera wants |
| `action_strength(id, key) -> float` | The same as a magnitude, 0 to 1 |
| `action_axis(id, negative, positive) -> float` | Two named actions as one signed axis |
| `action_vector(id, left, right, up, down) -> Vector2` | Two named axes, limited to unit length |

`action_strength` is what makes an analogue control analogue: a stick answers its
travel past the deadzone while a key answers 0 or 1. A two-finger drag remains a raw
`handle_world_input` or `handle_battle_input` leftover.

Everything a registered control reaches is reachable without a keyboard:

- The launcher's **controls** card lists a loaded mod's actions in their own group
  under the eight, and rebinds them through the same sheet.
- The on-screen controller can carry them. Off by default; switched on from the
  same card, each is a pill the player drags where they like, per orientation,
  beside A and B.

An event reaches a mod's action only where the screen would have offered a renderer
one, so an open menu, a running script, a battle or a trainer approach takes the
press first.
