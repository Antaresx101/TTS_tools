# Publishing a tool

Everything below is about putting a tool into a repo — mine or your fork.

## Drop a folder in

Make `tools/<tool-id>/`, put the object script in it as `tool.lua`, put a
`manifest.json` beside it, and run one command:

```bash
python scripts/validate.py --fix
```

```
tools/turn-timer/
  tool.lua        the object script, exactly as it runs in game
  tool.xml        the XML UI, if the tool has one - optional
  manifest.json   {"stable": {"version": "1.0.0", "notes": ["First release."]}}
```

The script comes back with [`updater/updater.lua`](updater/updater.lua) pasted
onto the end and all four config values filled in - `TOOL_ID` and
`TOOL_SIGNATURE` from the folder name, `TOOL_VERSION` from the manifest,
`REPO_BASE` from the block itself. Commit the folder and push. That is the
entire release: no registry to edit, nothing to regenerate, no code to change
anywhere else.

`--fix` only ever writes the block, those four values and the signature line on
`tool.xml`. The code above the divider is never touched, running it twice
changes nothing the second time, and on a folder that is already correct it
changes nothing at all. With no manifest it writes a starter one at `1.0.0` and
says to put real notes in it. The one thing it will not do is decide a version:
if `tool.lua` declares a version *higher* than the manifest publishes, it
leaves both alone and says so, because only the author knows whether that is a
release or a typo.

## Tools with an XML UI

A tool is always a script, and sometimes an XML UI beside it. Put that file in
the same folder as `tool.xml` and run `--fix`, which does two things with it:

- stamps `<!-- TTS-SELFUPDATE:<tool-id> -->` onto its first line. That is the
  gate a client checks a downloaded UI against, exactly as `TOOL_SIGNATURE` is
  checked in the script.
- writes `"xml": true` into the manifest's `stable` entry. That is what makes a
  client ask for the file at all.

```json
{
  "stable": {
    "version": "1.2.0",
    "notes": ["The panel now remembers which tab was open."],
    "xml": true
  }
}
```

Both halves arrive as one update or not at all. The UI is fetched only once the
script has passed its own gates, and a UI that fails either of its two — too
short, or unsigned — takes the script down with it, so an object is never left
running new code against an old layout.

The flag and the file have to agree, and `validate.py` fails if they do not: a
manifest that publishes a UI whose file is not there would break every update,
with nothing said in game. A release that mentions no XML at all leaves
whatever is on the object alone — plenty of tools build their own UI at
runtime, and none of that is the updater's to erase.

[`tools/test-tool/tool.xml`](tools/test-tool/tool.xml) is a minimal one, beside
the script it belongs to.

## Starting from a script outside the repo

`new-tool.py` does the same job in one step, from a file anywhere on disk:

```bash
python scripts/new-tool.py my-tool path/to/my-script.lua --notes "First release."
```

It creates `tools/my-tool/` with both files, refuses to overwrite an existing
folder, warns if the script has no `function onLoad`, and runs `validate.py`
when it is done. What it writes is byte-for-byte what dropping the folder in
and running `--fix` would have produced - both go through the same code.

A tool with an XML UI passes it as `--xml`, and the file is copied in as
`tool.xml`, signed, and published in the manifest in one step:

```bash
python scripts/new-tool.py my-tool my-script.lua --xml my-ui.xml
```

## What the script has to contain

Nothing at all. The block listens for the command itself, from the moment the
script loads, so there is no line to add to `onLoad` and no convention to
follow. Paste it at the bottom and it is done.

One requirement, and it is on the shape of the script rather than its
contents: it must define `function onLoad`, because that is one of the four
gates every client applies to a download. `new-tool.py` warns if it does not,
and `validate.py` refuses to publish a folder whose script has none.

Two optional functions, if you want them:

```lua
Updater_check()                              -- one check for this object, now
local from, now = Updater_stateVersion(state)  -- which version wrote the save
```

`Updater_check()` is what the chat command calls. You can call it yourself from
anywhere — a button on your own tool, or from Global with
`obj.call("Updater_check")`.

## By hand

Nothing above is magic, and the output is an ordinary file that hand-edits
afterwards. Doing it manually is four steps: make `tools/my-tool/`, paste
`updater/updater.lua` onto the end of the script and save it as `tool.lua`,
set `TOOL_ID` / `TOOL_VERSION` / `TOOL_SIGNATURE` in the pasted block, and write
`manifest.json` beside it:

```json
{
  "stable": {
    "version": "1.0.0",
    "notes": [
      "First release."
    ]
  }
}
```

A tool with a UI adds `tool.xml` to the folder, `<!-- TTS-SELFUPDATE:my-tool -->`
to its first line, and `"xml": true` to the `stable` entry.

[`tools/test-tool/`](tools/test-tool/) is a real, published tool with the block
already integrated, and it carries both halves — script, UI and manifest — so
it doubles as the starting shape to copy.

## The config values

| Value | What it is |
| --- | --- |
| `TOOL_ID` | The folder name under `tools/`. Both URLs are built from it. |
| `TOOL_VERSION` | The version this copy *is*. Compared against the manifest. |
| `TOOL_SIGNATURE` | A literal every legitimate payload contains. Rejects error pages and other people's scripts. |
| `REPO_BASE` | The only string that names a host. Already correct; the one thing you change if you fork. |
| `SELF_UPDATE` | The off switch, for whoever ends up running the tool. Always ships as `true`; setting it to `false` in a copy stops that copy for good, command included. `validate.py` refuses to publish a file where it is anything else. |

`--fix` fills in the first four for you. You never edit `SELF_UPDATE` in the
repo — it exists for the person on the other end.

If your tool saves state and you ever need to migrate it, one optional line
gives you the version that wrote the save:

```lua
local from, now = Updater_stateVersion(state)
```

## Release notes

`notes` is what the table is told when a copy updates itself. Write it as a
list and each entry arrives as its own bullet in Tabletop Simulator's chat:

```json
{
  "stable": {
    "version": "1.2.0",
    "notes": [
      "Right-click now resets the counter instead of subtracting.",
      "Fixed the total drifting after an undo."
    ]
  }
}
```

which reaches everyone at the table as one message:

```
[test-tool] updated to v1.2.0
  - Right-click now resets the counter instead of subtracting.
  - Fixed the total drifting after an undo.
```

A plain string still works and arrives as a single bullet, so nothing written
before this existed needs changing. Keep it to what a *player* would notice —
`validate.py` stops you at six bullets, and at 160 characters in one of them,
because this lands in every client's chat window at once.

`new-tool.py` takes the same thing one bullet at a time:

```bash
python scripts/new-tool.py my-tool my-script.lua --notes "First release." --notes "Second bullet."
```

### Copies that skipped versions

An object can sit in an unopened mod for a year and wake up several releases
behind. Add an optional `history` — past releases, newest first — and it is
caught up on every one it missed, not just the newest:

```json
{
  "stable": {
    "version": "1.2.0",
    "notes": ["Fixed the total drifting after an undo."]
  },
  "history": [
    { "version": "1.1.0", "notes": ["Right-click now resets the counter."] },
    { "version": "1.0.0", "notes": ["First release."] }
  ]
}
```

A copy on 1.1.0 is told about 1.2.0 only. A copy on 1.0.0 gets both, newest
first. Nothing at or below the version it was already running is repeated back
at it, and a tool with no `history` at all simply announces its new release —
this is entirely opt-in.

There is no extra request for any of that: the manifest is already downloaded
by the check, so it *is* the changelog. That also makes the full history
readable without the game — the manifest URL is a plain readable file, so
opening it in a browser shows every release the tool has ever had.

`validate.py` keeps the list honest: newest first, no repeats, everything in
it strictly older than `stable.version`, and no more than 24 bullets across
the whole file — because the oldest copy still out there is shown all of them
at once. Trim the tail when it gets long; nobody needs the v1.0.1 line two
years on.

## The URL convention

Nothing is configured per tool. Both URLs are derived from the folder name:

```
https://raw.githubusercontent.com/Antaresx101/TTS_tools/main/tools/<tool-id>/manifest.json
https://raw.githubusercontent.com/Antaresx101/TTS_tools/main/tools/<tool-id>/tool.lua
https://raw.githubusercontent.com/Antaresx101/TTS_tools/main/tools/<tool-id>/tool.xml
```

That is why one repo can serve any number of independent tools with zero setup:
a new folder under `tools/` *is* a new endpoint. All three URLs are plain
readable literals — paste one into a browser and you see exactly what an object
fetches. The third is only ever requested when the manifest says `"xml": true`,
so a tool without a UI makes two requests and no more.

A `?ts=<timestamp>` is added to every request, because raw.githubusercontent
caches for about five minutes and a fresh release would otherwise be invisible
for that long.

Every request is held back by a few seconds first, derived from the object's
own GUID. A Warhammer table can carry thirty copies of one tool, all of them
hearing one `!update` in the same instant, and without that they would hit
GitHub — and reload — in that same instant too. Copies
differ from each other because their GUIDs do, so nothing has to be configured
and `math.random` is left alone for whatever the tool above is doing with dice.

## Releasing a new version

1. Edit `tools/<tool-id>/tool.lua` — the tool's own code, above the divider —
   and `tool.xml` if it has one.
2. Bump `stable.version` in `manifest.json`. That file is what the repo
   publishes; `tool.lua` is made to agree with it in step 4.
3. Move the outgoing release to the top of `history`, then rewrite `notes` for
   what changed. `notes` is the whole message players get, and leaving last
   release's text there is worse than saying nothing.
4. `python scripts/validate.py --fix`
5. Commit and push. Objects pick it up the next time a host types `!update`.

The XML has no version of its own and needs none: it rides along with the
script, so a UI change is an ordinary release like any other.

The versions disagreeing is the thing that used to go wrong here. If the
manifest is ahead of the file, every client downloads the payload every time
anybody asks and throws it away at the last check — silently, with nothing
reported in game. Step 4 now syncs `TOOL_VERSION` to the manifest, and
`validate.py` still fails loudly if that step is skipped, so the mistake cannot
reach anyone's table.

Versions are plain `X.Y.Z`. Any suffix is ignored, and each part stays under 1000.

## Checks

```bash
python scripts/validate.py          # check everything, change nothing
python scripts/validate.py --fix    # repair what is mechanical, then check
```

It reads every folder under `tools/` and checks what the block depends on at
runtime: the embedded block matches `updater/updater.lua`, `TOOL_ID` matches
the folder name, `TOOL_VERSION` matches the manifest, `REPO_BASE` is this
repo's, the payload is bigger than its own `MIN_BYTES` gate, the file contains
its own signature, the code above the block defines `function onLoad`, there
is exactly one script write and it targets `self`, the block's one UI write
targets `self` too, `Global` is touched by exactly the three latch lines and
nothing else, `SELF_UPDATE` ships as `true`, and the release notes and
`history` are shaped the way the chat message needs. Where
there is a `tool.xml`, it is checked against the same two gates a client puts
it through and against the manifest's `"xml"` flag. It is standard library
only, and it runs on every push through
[`.github/workflows/validate.yml`](.github/workflows/validate.yml) as well, so
a broken folder cannot reach `main` unnoticed.
