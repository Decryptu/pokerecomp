# Mods

Mods are interpreted GDScript under `user://mods/<id>/`. The host loads them
before screens exist. Register through `Gen2ModHost`; use `GameData` for content
and `Gen2WorldAPI` for live read-only world state. Do not reach into scene nodes
or modify engine internals. Failed mods are listed and skipped independently.

## Quick start

Copy an [example](../mods/examples/) into `user://mods/`. Each mod needs:

```json
{
  "id": "example", "name": "Example", "version": "1.0.0",
  "api_version": 60, "entry": "mod.gd"
}
```

```gdscript
extends RefCounted

func register(host: Gen2ModHost, manifest: PokeModManifest) -> void:
    host.register_world_renderer(
        manifest.id, load("%s/renderer.gd" % manifest.directory), "Example"
    )
```

The renderer example supplies the required implementation. Register only the
features a mod needs; check registration results and `host.failures()`.

## Manifest and packaging

| Field | Meaning |
|---|---|
| `id` | Lowercase `[a-z0-9][a-z0-9_-]*`. Addresses the directory and the registry keys |
| `name` | Shown to the player |
| `version` | The mod's own version. Strict `major.minor.patch` |
| `api_version` | The oldest host this mod runs on, not a number to keep current: raise it when the mod starts using a newer seam. A host accepts `PokeModManifest.MIN_API_VERSION` to `API_VERSION`, which are the ends of the [Contract versions](#contract-versions) table it carries |
| `entry` | A `.gd` path inside the mod directory, or inside the pack when there is one |
| `pack` | Optional `.pck` or `.zip` beside `mod.json`, holding the mod's files |
| `description` | Optional |
| `icon`, `thumbnail` | Optional paths, when the art is not at a conventional name |
| `dependencies` | Optional map of required mod ids to SemVer ranges |
| `games` | Optional list of cartridge ids: `red`, `blue`, `yellow`, `gold`, `silver`, `crystal` |
| `menu_path` | Optional list of up to three category names, outermost first, placing the mod's row in the start menu's MODS entry. Each name is limited by `PokeModManifest.MENU_NAME_CELLS` |

IDs address directories and registries. Entry and art paths must stay inside
the mod. Dependencies load first; missing, disabled, incompatible or cyclic
requirements refuse the dependent mod. Ranges accept exact SemVer, wildcards,
comparison chains, caret and tilde ranges. Omitted/empty `games` means all games.

A pack is a `.pck` or `.zip` beside the manifest, exported from
`res://mods/<id>/`; its `entry` is relative to that root. The manifest remains
outside the pack. Mounting uses `replace_files=false`, so packs cannot replace
game resources. [Manifest validation](../game/mods/mod_manifest.gd) owns limits.

Optional root art: `icon.png`/`.webp`/`.jpg` for the launcher and
`thumbnail.webp`/`thumb.webp`/`thumbnail.png`/`thumb.png` for listings.
[Art validation](../game/mods/mod_art.gd) owns size and format limits.

## Installing and testing

The launcher's Mods tab installs archives, enables/disables mods and follows
sources. A disabled mod remains installed but does not run. Headless and `-s`
tool runs load no mods unless explicitly requested:

```bash
godot --headless --path . --quit-after 30 --mods
godot --headless --path . --quit-after 30 --mods=example,other
```

These runs use mod defaults without reading/writing player mod settings.
`--clock=HH:MM[:D]` pins the world clock for a reproducible preview.

## API map

[Gen2ModHost](../game/mods/mod_host.gd) is the authoritative registration and
request contract: declarations document provider methods, dictionary fields,
validation and refusals. Use this index to find the owning API instead of
maintaining a second copy of every schema here.

| Task | Host API / owner |
|---|---|
| Add or patch species, moves, items, types | `register_content`, `patch_content`; [content overlay](../game/data/content_overlay.gd) |
| Change type matchups or encounters | `patch_type_matchup`, `patch_encounter`, `patch_fishing_group`, `patch_treemon_set`, `patch_bug_contest_mon`, `patch_roaming_mon`, `patch_fishing_time_group` |
| Replace text | `patch_text`, `patch_world_text`; [text overlay](../game/data/text_overlay.gd) |
| Place story rewards | `patch_check`, `validate_placement`, `reachable_checks`; [catalog](../game/data/world_catalog.gd), [reachability](../game/data/world_reachability.gd) |
| Add move effects | `register_move_effect`, `register_effect_command` |
| Observe/annotate events | `subscribe`, `register_event_mutator`, `register_battle_info` |
| Replace rendering | `register_world_renderer`, `register_battle_renderer`, `select_view` |
| Add world sprites | `register_world_actor`; [actors](../game/world/world_actors.gd) |
| Visible wild encounters | `register_visible_encounters`; [encounters](../game/world/world_encounters.gd) |
| Wild replacements and roamers | `register_wild_substitute`, `register_roam_encounter_chance`, `request_roamer`, `roamers` |
| Battle replacement | `register_battle_takeover` |
| Experience rules | `register_catch_experience`, `register_experience_scale`, `register_experience_bystanders` |
| Shiny rolls, running, field moves, Repel | `register_shiny_rolls`, `register_run_button`, `register_field_move_source`, `register_repel_renewal` |
| Read the run | `inventory`, `party`, `progress`, `progress_changed`; [world API](../game/world/world_api.gd) |
| Queue gameplay requests | `request_hidden_item`, `request_item_gift`, `request_pokemon_gift`, `request_gs_ball` |
| Display messages | `request_battle_message`, `request_notice` |
| Add UI | `register_menu_entry`, `register_party_member_menu`, `register_stats_page`, `register_page` |
| Settings and controls | `register_option`, `option`, `set_option`, `register_action`, `action_held`, `action_strength`, `action_axis`, `action_vector` |
| Per-save state | `register_save_lifecycle`, `read_save_data`, `write_save_data` |

Content IDs start at `Gen2ContentOverlay.FIRST_MOD_NUMBER`. Cartridge numbers
remain unchanged. Patch encounter tables with their original slot count; do not
substitute Generation 2 numbering or formats for another generation.

Placement validation models reachable gates, not a complete playthrough. It is
conservative toward accepting a seed; verify a generated route's actual critical
path before claiming it is finishable.

Subscribers observe resolved events. Mutators change presentation, not the
already-resolved battle state. Requests are queued through the host so the world
can validate inventory, flags and transactions; requesting is not committing.

## Renderers and actors

World renderers implement `set_world`, `set_time_of_day`, `refresh` and
`refresh_animation`. Battle renderers implement `set_battle_data`, `set_view`
and `refresh`. Optional methods are listed by the host's `RENDERER_*` constants.

A renderer defaults to the hardware viewport. Returning false from
`uses_hardware_viewport()` selects a native-size surface; handle
`set_native_size()` and use the supplied interface rectangles. Gameplay buttons
are consumed before `handle_world_input`/`handle_battle_input`. Register named
actions for rebindable controls instead of matching raw keys.

Use the supplied draw list for resolved sprites and background edits. Connected
maps use their own tilesets and contain read-only scenery. Actor and encounter
providers describe poses as `RefCounted` objects, not scene nodes. The world owns
collision, interactions, requests and cartridge sprite resolution.

Battle views carry plain display values, not a live battle model. EXP uses
pixels out of 64. The current view fields are:

| Group | Fields |
|---|---|
| Who is standing | `enemy_species`, `player_species`, `enemy_name`, `player_name`, `enemy_level`, `player_level`, `enemy_shiny`, `player_shiny`, `enemy_unown_form`, `player_unown_form`, `enemy_substitute`, `player_substitute`, `enemy_minimized`, `player_minimized`, `enemy_special_pic` |
| The fight | `battle_kind` (`wild` or `trainer`), `trainer_class`, `trainer_index`, `trainer_name` |
| Bars | `enemy_hp`, `enemy_max_hp`, `player_hp`, `player_max_hp`, `exp_pixels` |
| HUD | `hud_visible`, `enemy_hud_visible`, `player_hud_visible`, `enemy_status`, `player_status`, `enemy_gender`, `player_gender`, `enemy_caught`, `trainer_hud_balls`, `trainer_hud_border` |
| Entrance | `battlers`, `intro_sprites`, `grayscale`, `enemy_trainer_pic`, `player_backpic`, `player_backpic_palette` |
| Colour | `enemy_pic_dmg`, `gen1_black`, `anim_obp0` |
| Hardware | `raster_scx`, `raster_scy`, `bg_map`, `bg_vbank1`, `bg_palette_maps`, `ob_palette_maps`, `anim_sprites`, `anim_tiles` |

## Settings and saved state

Settings outside a run are installation defaults; an active slot owns its
`run_options`. Saved values invalidated by a mod update fall back to defaults.
Per-save dictionaries are deep-copied and limited to 64 KiB of UTF-8 JSON. Use
the discovered manifest object as the capability; recreating its ID grants no
access. See [save semantics](SAVES.md).

Actions support physical keys, pad buttons and signed pad axes. Defaults that
collide with gameplay controls are dropped and reported; the action remains
available for rebinding. Controls and touch buttons are managed by the launcher.

## Publishing a source

Publish an HTTPS JSON feed:

```json
{
  "schema_version": 1, "name": "Example mods",
  "mods": [{
    "id": "example", "name": "Example", "version": "1.0.0",
    "download": "https://example.com/example-1.0.0.zip"
  }]
}
```

Rows may add `description`, `games`, `icon` and `thumbnail`. Downloads must use
HTTPS and their manifest ID must match the listing. Versions compare as strict
`major.minor.patch`. Following a source installs nothing until a mod is chosen.
GitHub `owner/repo` resolves to `https://<owner>.github.io/<repo>/index.json`.
Parsed feeds are cached for offline use; Sources refreshes them.

## Contract versions

Declare the oldest version containing every API the mod uses. The accepted range
is defined by `PokeModManifest.MIN_API_VERSION` and `API_VERSION`; versions below
30 used class names no longer available. For supported version history:

| Version | Added |
|---|---|
| 60 | `field_move` on an item row: USE runs that HM field move, and the bag holding the item supplies the move wherever an HM would |
| 59 | Actor `yes_no` requests answering `accepted`; `Gen2ModHost.party()`; `destination`, `box` and `newly_caught` on a `pokemon_gift` answer |
| 58 | Actor `text` and `step` requests; `id` and `frame` on an actor entry; the Dude's fight never sends the player's Pokemon out |
| 57 | `Gen2WorldAPI.player_walk_cells()`, and the cells the player still has to cross in a visible-encounter context's `occupied` |
| 56 | Actor `catch_demo` requests; `request_completed(result)` answering an actor's `battle` and `catch_demo` as well as its gift |
| 55 | Actor `pokemon_gift` requests and `request_completed(result)`; `request_pokemon_gift()`; lasting `starter_species` and `beat_red` progress; opt-in Gold/Silver GS Ball chain and `gs_ball_stage` |
| 54 | `hp` and `status` on an actor's `battle` request, `status` on a wild substitute's answer, and `status` on `ended` |
| 53 | `after_credits` on `register_page()`, and `Gen2ModHost.credits_page_ids()`; the `text_closed` world event every `closetext` publishes, which replaces `money_window_closed` |
| 52 | `Gen2WorldAPI.camera_reaches()` and `camera_reach_revision()`: `expanded_block_at()` and the draw list leave another room of an indoor map out; big objects drawn in `facings.asm`'s own tile order |
| 51 | `ended` on the battle channel; `register_wild_substitute()`; `register_battle_takeover()`; a `solid` actor entry and an actor's `battle` request; `request_gs_ball()` and `gs_ball_offered` in `progress()` |
| 50 | `hp_bar` on the battle channel, the one event that moves a bar, where the cartridge draws it; `hp`, `max_hp`, `to_hp` and `target_hp` leave the lines around it |
| 49 | `Gen2WorldMap.code_at()`, `permission_at()`, `is_door_at()` and `ledge_hops_at()`, the same three on `Gen2WorldAPI`, and `Gen2WorldCollision.cell_code()`, `cell_permission()`, `cell_is_door()` and `cell_hops()`, answering a cell on either generation |
| 48 | `register_roam_encounter_chance()`, `roamers()` and `request_roamer()`; `beasts_released`, `fought_suicune` and `caught_species` in `progress()`; a visible population keeping away what a Repel would |
| 47 | `Gen2WorldMap.name`, the `map_const` constant's name on every cartridge, and `GameData.world_map_named()` |
| 46 | `box_full` on a `caught` event, and `box_free_space` in `progress()`; a hidden Headbutt tree left out of `drawn_tile_at()` and `drawn_revision()` |
| 45 | `Gen2WorldDrawList.drawn_tile_at()`, `band()` and `drawn_revision()`, with `band` and `drawn_revision` on `frame()`; `changed_blocks` and `written_tiles` on `Gen2BattleWorldContext`; `Gen2WorldScreen.preview_ss_anne_leaves()` and `preview_poison_step()` |
| 44 | `Gen2BattleHud.draw_party_balls()`; `ground` on every draw-list row, a screen row's `position_cells` and `ground` in map terms, and a renderer's `draw_reach_pixels()` listing connected rows out to its reach; `reachable_checks()`, what a placement reaches with items and badges held from the start; `Gen2WorldCatalog.progression_items()`; a patched `{"item": 0}` or `{"badge": -1}` as a site that hands nothing; `validate_placement` asking a site that waits on an engine flag other than a badge's again once a script sets that flag; Oak's aides as item sites; `{owned}` and `{special}` in `requires` |
| 43 | `Gen2BattleRenderer.square_pixels()`, `square_key()`, `square_side()`, `battler_pic()` and `substitute_sprite()`; `Gen2BattleHud.draw_panels()`, `panels_key()` and `draw_border_cells()`; the status and gender arguments of `draw_enemy()` and `draw_player()`; the battle view's `enemy_status`, `player_status`, `enemy_gender`, `player_gender`, `enemy_caught`, `enemy_minimized`, `player_minimized`, `enemy_special_pic`, `enemy_pic_dmg`, `gen1_black` and `anim_obp0`; Generation 1's "minimize" tile, and its doll drawn from pokered's own `SPRITE_MONSTER`; a move row's `effectiveness` as its effect applies it; a table patch bumping the encounter context's `generation`; a patched `giveegg` staying an egg; a headless `--mods` or `--mods=a,b` run at mod defaults, apart from the player's mod settings; `Gen2WorldDrawList` through the optional `set_draw_list`: every sprite, effect and background edit the built-in view draws, resolved once for any renderer, with `sprites_hidden` on it rather than set on the renderer; `validate_placement` proving the story's gates, `Gen2WorldCatalog.story()`, a row's `cell`, and `requires` holding what every path to a site tested |
| 42 | `START_ACTION_OPEN_PC`, and a table patch rechecking the visible wilds already standing |
| 41 | `clear_patches()`, an encounter patch refused off the cartridge's slot count, a mod species met in the wild, `GameData.map_landmark()` and `world_fishing_group_count()`, and `Gen2WorldAPI.encounter_tables_key()` moving when a patch lands |
| 40 | `Gen2WorldTileset.name`, the `TILESET_*` constant's name on every cartridge, `GameData.world_tileset_named()`, and `Gen2Layout.tileset_name()` and `tileset_number()` between Crystal's numbering and Gold and Silver's |
| 39 | A Generation 1 map draws block 0 as block 0, through `Gen2WorldAPI.drawn_block_of`; `Gen2BattleColors`, the colours a battle is drawn in on either generation, for any renderer; `Gen2BattleRenderer.back_pixels`; `Gen2WorldPalette.overworld_sprite_colors`, `Gen2WorldMap.is_outside()` and `Gen2WorldCollision.gen1_ledge_direction` |
| 38 | `chance` on every slot `active_encounter_tables()` answers; a shiny pulse announced with `SFX_SHINE` on Red, Blue and Yellow; Yellow's Pikachu in `occupied` |
| 37 | The gameplay catalog on Red, Blue and Yellow, `validate_placement` walking their map graph, the Old and Good Rod as `GameData.GEN1_OLD_ROD_GROUP` and `GEN1_GOOD_ROD_GROUP`; a `register` that read `generation()` or `target_game()` runs again when the answer changes |
| 36 | A notice's `{"badge": 8..15}` drawn from the Gen 1 card's own `badge_faces` on Red, Blue and Yellow |
| 35 | `Gen2ModHost.generation()` and `generation` on the battle snapshot; `repel_to_use` handed the cartridge's Repel table; an HM in the bag as a field-move source, Exp. All and `OPEN_BILLS_PC` on Red, Blue and Yellow |
| 34 | Red, Blue and Yellow draw a shiny shiny, offer registered party rows, answer `hidden_items()`, `take_hidden_item()` and `hidden_item_nearby()` from their own hidden-item rows, and say `Gen2WorldAPI.cartridge_follower_out()` |
| 33 | A registered stats page turns on Red, Blue and Yellow |
| 32 | `map_group`, `map_number` and a Generation 1 counter's `text_id` on the mart a `MENU_MART` filter is asked about |
| 31 | `patch_text()` and `patch_world_text()`, and `GameData.text()` with the run listings beside it |
| 30 | The classes both generations reach take the `Poke` prefix: `PokeTiles`, `PokePalette`, `PokeRaster`, `PokeApu`, `PokeAudioRender`, `PokeGameTime`, `PokeModManifest`, `PokeModVersion` and the input and launcher classes beside them. `RomLayout` becomes `Gen2Layout`, beside the new `Gen1Layout`. Nothing else changed, so a mod moves by renaming what it names |
