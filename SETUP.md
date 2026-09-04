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
  tool.xml        the XML UI, if the tool has one - optional. It is
                  spliced into tool.lua; nothing downloads it.
  manifest.json   {"stable": {"version": "1.0.0", "notes": ["First release."]}}
```

The script comes back with [`updater/updater.lua`](updater/updater.lua) pasted
onto the end and all four config values filled in - `TOOL_ID` and
`TOOL_SIGNATURE` from the folder name, `TOOL_VERSION` from the manifest,
`REPO_BASE` from the block itself. Commit the folder and push. That is the
entire release: no registry to edit, nothing to regenerate, no code to change
anywhere else.

`--fix` only ever writes the block, those four values, the signature line on
`tool.xml` and the copy of it spliced into `tool.lua`. The tool's own code is
never touched, running it twice
changes nothing the second time, and on a folder that is already correct it
changes nothing at all. With no manifest it writes a starter one at `1.0.0` and
says to put real notes in it. The one thing it will not do is decide a version:
if `tool.lua` declares a version *higher* than the manifest publishes, it
leaves both alone and says so, because only the author knows whether that is a
release or a typo.

## Tools with an XML UI

A tool is always exactly one file. Where it has an on-screen UI, that layout
is authored as `tool.xml` in the same folder, and `--fix` does two things with
it:

- stamps `<!-- TTS-SELFUPDATE:<tool-id> -->` onto its first line, so a loose
  file says which tool it belongs to.
- splices it into `tool.lua` between the tool's code and the block, as

  ```lua
  local TOOL_XML = [[
  <!-- TTS-SELFUPDATE:my-tool -->
  <Panel>...</Panel>
  ]]
  ```

  The bracket level goes up on its own if the layout contains `]]`, so nothing
  in a UI can end the string early.

The block applies that string with `self.UI.setXml` when the object loads, and
nothing is ever written to the object's XML field. **The consequence worth
knowing: a tool cannot address its own UI in the frame it loads in.** Do the
first `setValue` or `setAttribute` a frame or two later —
[`tools/test-tool/tool.lua`](tools/test-tool/tool.lua) uses
`Wait.frames(refresh, 2)`, and the coherency tool does the same.

The block calls the tool's `onLoad` *before* applying the layout, so anything
the layout depends on is already in place — custom assets named by `image=""`,
for one, which the tool registers with `setCustomAssets` on load.

This is why an update cannot land half a tool: there are no halves. One file
is fetched, checked and written. A tool with no `tool.xml` splices nothing and
the block touches no UI at all, which leaves tools that build their own at
runtime alone.

`tool.xml` is source, not something published. It stays in the folder because
it is the copy that gets edited and reviewed; no client ever asks for it.
[`tools/test-tool/tool.xml`](tools/test-tool/tool.xml) is a minimal one.

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
`tool.xml`, signed, and spliced into `tool.lua` in one step:

```bash
python scripts/new-tool.py my-tool my-script.lua --xml my-ui.xml
```

## What the script has to contain

Nothing at all. The block listens for the command itself, from the moment the
script loads, so there is no line to add to `onLoad` and no convention to
follow. Paste it at the bottom and it is done.

One requirement, and it is on the shape of the script rather than its
contents: it must define `function onLoad`. The block brings an onLoad of its
own, which is what applies the layout, but a script with none of its own never
sets anything up when the object loads. `new-tool.py` warns if it does not,
and `validate.py` refuses to publish a folder whose script has none.

Two optional functions, where a tool wants them:

```lua
Updater_check()                              -- one check for this object, now
local from, now = Updater_stateVersion(state)  -- which version wrote the save
```

`Updater_check()` is what the chat command calls. A tool can call it from
anywhere as well — one of its own buttons, or from Global with
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

A tool with a UI adds `tool.xml` to the folder and
`<!-- TTS-SELFUPDATE:my-tool -->` to its first line. Splicing it into
`tool.lua` by hand is possible but pointless — run `--fix`.

[`tools/test-tool/`](tools/test-tool/) is a real, published tool with the block
already integrated, and it has a UI as well as a script, so it doubles as the
starting shape to copy.

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

Where a tool saves state and that state ever needs migrating, one optional
line reports the version that wrote the save:

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
```

That is why one repo can serve any number of independent tools with zero setup:
a new folder under `tools/` *is* a new endpoint. Both URLs are plain readable
literals — paste one into a browser and it shows exactly what an object
fetches.
There is no third: every tool makes exactly two requests, whether it has a UI
or not, because the UI is part of the second one.

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

1. Edit `tools/<tool-id>/tool.lua` — the tool's own code, above the spliced
   layout — and `tool.xml` if it has one.
2. Bump `stable.version` in `manifest.json`. That file is what the repo
   publishes; `tool.lua` is made to agree with it in step 4.
3. Move the outgoing release to the top of `history`, then rewrite `notes` for
   what changed. `notes` is the whole message players get, and leaving last
   release's text there is worse than saying nothing.
4. `python scripts/validate.py --fix`
5. Commit and push. Objects pick it up the next time a host types `!update`.

The XML has no version of its own and needs none: it is part of the script by
the time anything is published, so a UI change is an ordinary release like any
other. Step 4 is what puts it there — edit `tool.xml` and skip `--fix`, and
the published file still carries the old layout. `validate.py` fails on that.

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
there is a `tool.xml`, the copy spliced into `tool.lua` is checked against it
byte for byte, so a stale layout cannot be published. It is standard library
only, and it runs on every push through
[`.github/workflows/validate.yml`](.github/workflows/validate.yml) as well, so
a broken folder cannot reach `main` unnoticed.
