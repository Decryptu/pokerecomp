# Contributing

Read [the README](../README.md) first. This file holds the rules and the traps.
It does not describe the architecture: every source finding, constant and
contract lives next to the code that enforces it.

## Keep cartridge data out

Never commit a commercial cartridge or derived data: ROMs, `.sav` files,
sprites, text, maps or audio. Three layers enforce it:

1. `.gitignore` blocks known extensions, `roms/` and runtime caches.
2. `.githooks/pre-commit` checks staged blobs by extension and rejects any blob
   at least 512 KiB outside `addons/` and `assets/`, catching renamed or
   trimmed dumps. Enable once per clone: `git config core.hooksPath .githooks`.
3. Tests use synthetic files and a known SHA-1 vector, never a real cartridge.

`roms/.gdignore` keeps Godot from importing or exporting that directory while
tools still read it with `FileAccess`. Do not delete it.

## Map

| Path | Owns |
|---|---|
| `game/rom/` | SHA-1 allowlist, verification, bank addressing. Node-free statics |
| `game/import/` | Decoders and the `user://` cache. Take bytes, return data |
| `game/data/` | `game_data.gd`, the sole engine-facing cartridge-content API |
| `game/save/` | Project saves, versioned and scene-free. See [SAVES.md](SAVES.md) |
| `game/world/` | Request resolution, separate from the screens that draw it |
| `game/battle/` | Scene-free engine, seeded RNG, hardware integer order |
| `game/render/` | Tile-grid pages; a `*_page.gd` draws, its model decides |
| `game/mods/` | Manifest validation and the registry. See [MODS.md](MODS.md) |
| `audio/` | The cartridge's own driver over an emulated APU |
| `autoload/diagnostics.gd` | The log sink, the crash marker and the report bundle |

Five boundaries are load-bearing and not obvious from one file:

- **Raw byte runs never go into JSON.** A decimal array costs ~4 bytes on disk
  and ~26 resident per cartridge byte. Use `RomCache.write_payload_map()` or
  `write_section()`; both leave an `[offset, length]` span and move the bytes to
  a `.bin` blob. Only a named `bytes` field moves.
- **World sections load on first use.** The launcher, pic viewer and battle
  never read scripts, text or audio.
- **Never match a keycode in a screen; match a `Gen2Button`.** An embedded host
  takes `handle_button(button)`, so a test presses a button, not a key.
- **Anything printed is already in the bug report.** `Gen2Diagnostics` installs
  a [Logger] with `OS.add_logger`, so every `print`, `push_warning`,
  `push_error` and runtime error reaches the session log and the report a player
  attaches to an issue. Never add a second reporting path beside a message; add
  the message. `Gen2Diagnostics.note()` is the same print with a topic on it;
  `trace()` is for a breadcrumb and is kept out of check and tool runs.
- **Reach an autoload by its static accessor**, `Gen2InputRuntime.instance()` or
  `Gen2GameRuntime.instance()`, never the `InputRuntime`/`GameRuntime` global. A
  script handed to `-s` compiles before the tree exists, so naming one by
  identifier takes down every tool that loads it.

The engine returns event lists, not strings or final state. Keep wording,
animation and timing out of it.

## Audio parity

Nothing between the stream bytes and the samples decides what a note sounds
like: vibrato, slides, duty rotation, envelopes, drum kits and effects stealing
channels are all the driver's per-frame state. Behaviour belongs in the engine
only when `audio/engine.asm` puts it there, and cartridge quirks are reproduced,
not corrected.

`tools/render_audio.gd` dumps any record to a WAV plus a per-frame register
trace. That trace is the parity artefact: any faithful implementation of the
same driver writes the same registers in the same order on the same frames.

## Offsets

`rom_layout.gd` holds absolute positions per dump, and wrong offsets decode
plausible neighbouring data, so `RomImporter.verify_layout()` runs every check
before decoding. **When you add an offset, add its check** in the same commit;
the checks themselves are the list, and they are in that function.

Find data by searching a dump for independently known bytes (an encoded name,
published base stats), then confirm structure against
[pret](https://github.com/pret). Never copy an address across games: bank and
address pairs differ. For graphics, encode the reference PNG as cartridge 1bpp,
one byte per row with bit 7 leftmost, and search for the exact sequence.

## Verifying

Runtime checks prove shape and endpoints, not interior values.

```bash
godot --headless --path . -s res://tools/dump_tables.gd -- gold moves
godot --headless --path . -s res://tools/preview_pics.gd -- gold /tmp/gold.png front
godot --headless --path . -s res://tools/validate.gd -- all
```

Contact sheets expose decompression, tile order, palette and pointer errors.
`tools/validate.gd` is the real-cache suite; see the README for its topics.

`tools/screenshot.gd` renders a scene to PNG and cannot be headless:

```bash
godot --path . -s res://tools/screenshot.gd -- res://game/main/main.tscn /tmp/shot.png 20
```

An optional `<method> <times> [int arg]` drives a scene before capture. Keep
state changes as callable methods, not only input branches, so screens stay
inspectable without a key press.

`tools/record_clip.gd` records one clip to video, mods and all, for a trailer
rather than for a check. Godot's Movie Maker pins the frame delta, so the world
spends exactly one hardware frame per recorded frame and the same arguments give
the same clip:

```bash
godot --path . --mods --write-movie /tmp/clip.avi --fixed-fps 60 \
  -s res://tools/record_clip.gd -- crystal 24 3 cell=20,10 hold=left seconds=5
```

`screen=saves` shoots the launcher's save page instead of the world, which is
where a run's challenge is chosen. Movie Maker's frame is the project's own
viewport, so `size=` defaults to it: a layout of any other size is scaled into
the frame, which is what makes a page's text soft. What the clip plays with is
arguments: `party=`, `items=`, `challenge=` and `progress=` build the recording
save and the run behind it, and nothing is written to disk.

Buttons are scripted per hardware frame through `Gen2WorldScreen.replay_input`.
`text=auto` answers a box that is waiting for a press and `at=<state>:<action>`
lands one on a menu the first time the screen reaches it, so a clip that has to
fight, open the pack or throw a ball is aimed at what is on screen rather than at
a frame number; `read=` and `beat=` set how long a finished page and a chosen
menu row are left standing, which is what makes a clip readable rather than
merely correct. `meet` fights the wild a mod has drawn on the map instead of
inventing one, so the entry's id travels with the battle and its sprite goes
when the fight is over. The `probe=` modes answer where a walk may go, what a
seed puts on the map, what the start menu's rows are and, with `probe=trace`,
the frame every visible thing changed on. The header has the options and the ffmpeg line.

The recording window is put in front and kept there: the engine does not draw an
occluded window and Movie Maker writes a frame per drawn frame, so a covered one
records a clip with its middle missing. A run that loses frames anyway fails
rather than writing a short clip.

`tools/profile.gd` answers what a drawn frame costs, per screen, in
milliseconds. It needs a window, and turns the frame cap and vsync off so the
number is the work rather than the monitor:

```bash
godot --path . -s res://tools/profile.gd -- all crystal 600
```

Each subject is driven by counted hardware frames with the screen's own
`_process` off, so a row is comparable between two runs on one machine. Between
machines only the ratio carries.

The GDScript analyzer runs only inside the editor: no CLI mode prints its
warnings and `--check-only` suppresses them. Two ways to read it, both required
to stay at zero.

```bash
Godot --headless --editor --path . -- --warning-scan [path ...]
```

`addons/warning_scan` opens each named script in the editor's script editor and
prints `file:line CODE message`, then a tally and how many scripts it analysed;
it exits 1 when there were any. Paths may be files or directories, `res://` or
`user://`, and default to the project's script trees. It reports the first
warning per script: fix it, run again, and the next appears. Without the flag the
plugin does nothing.

`tools/dump_editor_errors.gd` is the other half, run from Editor > File > Run.
It writes the Debugger panel's whole list to `user://editor_errors.txt`, engine
errors included, which is how a mod's `user://` scripts are seen. The panel holds
what the session has analysed, so reload the project first for a full sweep.

A tool that takes an output path guards it with `Gen2ToolPath.refuses()` before
doing any work. A tool runs with `--path <this project>`, so a bare `out.png`
lands in the checkout and the editor makes an `.import` beside it. The test is
where the path resolves, not how it is spelt: `res://out.png` is absolute to
`is_absolute_path()` and lands in the project all the same. `user://` is allowed.

`integer_division` is the one warning turned off in `project.godot`: this is
8-bit hardware arithmetic throughout, where `a / b` on two integers is the
intended operation, and a float result is written with an explicit `float()`.

Before rewriting or finishing a subsystem: port the state machine rather than
approximating its output, find a second executable implementation to diff
against, pick an artefact that compares exactly, sweep the whole corpus, and
settle every disagreement against pret.

## Switch

Nintendo ships no Godot platform and upstream carries none, so the Switch
template is built from a fork of the same engine pin that adds `platform/nx`.
`.github/workflows/export-templates.yml` holds both pins side by side:
`GODOT_COMMIT` for every other target, `GODOT_NX_REMOTE` and `GODOT_NX_COMMIT`
for this one. The two must stay on the same Godot series; the build already
refuses a pin whose `version.py` disagrees with the release's stock templates.

`tools/build_export_templates.sh switch` builds it, against devkitPro's
devkitA64 and switch-mesa, and writes `switch_release.elf`. The toolchain is
only packaged for CI as `devkitpro/devkita64`, so the workflow runs that host in
that container.

There is no export preset. A stock editor knows no NX platform and drops a
preset it cannot resolve, so the release exports the pack with the Linux preset
and wraps it with `nacptool` and `elf2nro`, which is what the fork's own export
plugin does when the editor is built from it. The published zip extracts at the
root of a microSD and puts one file at `switch/pokerecomp.nro`.

Two things a Switch build changes for every platform, both fixed at the seam
rather than behind a platform name:

- Godot's `ui_accept` carries three keys and no pad button, so a machine with no
  keyboard could move every focus ring and choose nothing under it.
  `Gen2InputActions.UI_PAD_BUTTONS` gives it one.
- The launcher draws in device-independent points, and a platform that cannot
  open a second window is one whose window is the whole screen and whose sizes
  are physical pixels. `Gen2LauncherUI.draws_in_screen_pixels` asks the display
  server rather than listing platforms.

## Pitfalls

- GUT silently skips scripts that fail to parse. `test_smoke.gd` loads every
  script and calls `can_instantiate()`, not only `assert_not_null(load(path))`.
- Do not use `ResourceLoader.CACHE_MODE_IGNORE` on a running script; reparsing
  during a call can corrupt the VM. Use
  `godot --headless --check-only --script res://path.gd`.
- New scripts need an editor scan before they resolve; edits to existing ones do
  not: `godot --headless --editor --path . --quit`. The class index lives in the
  uncommitted `.godot/`, so anything else resolving against this checkout sees
  the gap. Run the scan in the commit that adds the class.
- Defer `_ready()` scene changes with `change_scene_to_file.call_deferred(path)`.
- A bare `PanelContainer` is transparent; give modals a
  `theme_override_styles/panel` `StyleBoxFlat`.
- A scene root without its `script =` line loads but does nothing.
- JSON numbers return as floats; cache readers must use `int()`.
- GDScript closures capture locals by value. Mutate an Array/Dictionary or use a
  method. A signal closure capturing its source can leak it; connect a method.
- A screen counting hardware frames off `_process` delta spends an unknown
  number of them across an `await`. Take its processing away with
  `set_process(false)` before sampling a value that is still moving.
- Godot 4.8 is a dev build. Compare odd behaviour with 4.6 stable before blaming
  project code.

## Style

- Tabs for indentation; static typing where practical.
- `snake_case` for variables, functions and files; `PascalCase` for classes and
  nodes.
- `.tscn` and `.tres` are plain-text format 3. Edit them directly. Do not invent
  `uid://` values; omit invalid fields and let Godot regenerate them.
- No em-dashes. Check with
  `grep -rn $'\u2014' . --exclude-dir=.git --exclude-dir=addons`.

## Writing and file budget

The repository is kept small on purpose.

**Extend, do not add.** A new feature belongs in the file that already owns its
subject. Before creating any file, name the existing one it cannot go in.

- **Tools.** Do not add a script per feature. `tools/validate.gd` takes a new
  topic as a table entry; `tools/preview_*.gd` are per screen, not per scene or
  per check. A one-off you ran once is not a tool: delete it.
- **Tests.** One file per subject, not per behaviour. Add cases to the existing
  file. A behaviour is tested once, at the layer that owns it; re-asserting it
  at a second layer buys nothing and costs the suite. Keep slow work
  (real caches, whole-movie runs, frame sweeps) out of the default suite.
- **Docs.** State each fact once, where it is enforced, and link instead of
  repeating. Source findings and constants go next to the code; contracts go in
  `docs/`.
- **Comments.** Write none you do not have to: a name, a guard clause or a small
  named helper says it once and cannot go stale. The one worth writing is a
  source fact, the pret symbol a behaviour comes from plus the line saying why it
  is not obvious. Never restate the line below, no section banners, no doc
  comment on a self-evident function, and no paragraph of prose about a decision
  the code makes plainly. A comment explaining a workaround is a bug report: fix
  the code instead. `rom_layout.gd` records how an offset was located, which is
  evidence for a number rather than restatement, and is still held to the cap.

When something changes, replace the old text. Never append a correction.

## The budget

`tests/unit/test_source_budget.gd` caps how much branching and how much prose the
tree may carry, because both track defect count the way line count does. It fails
the suite.

| Rule | Ceiling |
|---|---|
| Cyclomatic complexity of one function | 20 |
| Lines in one comment block | 8 |
| Comment lines under `game/`, `tools/` and `autoload/` | the number recorded in the test, which only goes down |

Complexity counts `if`, `elif`, `while`, `for`, `and`, `or`, an inline `if` and
one per `match` arm. Over the ceiling, the remedy is a lookup table, a guard
clause or a named helper, never a nested ternary. No function is over it today,
and the test's `OVER_COMPLEXITY` list is empty: keep it that way.
