# Antares77´s TTS Tools Repository

Tabletop Simulator object scripts that can update themselves with a newer version
when you ask them to.

When using any of my tools with this functionality, in TabletopSimulator,
typing `!update` in the chat as the host will automatically update all such
tools in the session with the newest version (if it isn´t on it already).

Nothing happens until you ask. Loading a mod sends no requests and changes no
scripts, it is triggered manually always.

---

## What "updates itself" means

You type `!update`. Every object on the table carrying the updater block hears it,
asks this repository whether a newer version of *itself* exists, and if one does,
downloads the complete script, checks it, and replaces its own — and nothing
else on the table is touched.

A tool is always exactly one file. Where it has an on-screen UI, that layout
travels inside the script and is applied when the object loads, so an update
cannot leave new code running against an old layout — there are no halves to
get out of step.

Every tool posts the update status in chat.
However many copies of one tool are on the table, each of these is posted
once.

Examples:
```
[life-counter1] updated to v1.2.0
  - Right-click now resets the counter instead of subtracting.
[dice-roller1] up to date at v2.1.0
[card-dealer1] could not reach its repository (404)
```

More info:
- **It is a per-session refresh, not a permanent patch.** A script changed at
  runtime lasts until the host saves the game. So as a mod author, you would
  typically run this once before committing the workshop update upload.
- **Every file here is a complete tool, never a stub.** If you are offline, or
  GitHub is blocked, or you switched updates off, the object simply keeps
  working at the version you already have.
- **You can switch a script´s updating off in one line.** Near the top of the Lua
  block there is `local SELF_UPDATE = true`. Change it to `false` and that copy
  never checks again.

## What is in here

```
tools/       one folder per tool - tool.lua plus manifest.json, and tool.xml
             for a tool with a UI. Only tool.lua is downloaded; tool.xml is
             the source layout, spliced into it by validate.py.
             test-tool/ is the worked example.
updater/     the self-update block itself, pasted into every tool
scripts/     validate.py to check and repair the repo, new-tool.py to scaffold
             a tool, block.py holding the one operation both of them do
.github/     the same check, run on every push
SETUP.md     how to publish a tool of your own - only needed if you fork
```

## Want updating tools of your own?

This is a one-person project. I maintain it and publish my own tools here, so
if you want to run your own, the expected path is to **fork it**:
fork, point `REPO_BASE` at your repo, and you have an independent tool server.
It is one string, in one file:

```bash
# edit REPO_BASE at the top of updater/updater.lua, then:
python scripts/validate.py --fix
```

That pushes the new host out to every tool folder. Nothing
else in the repo names a host, and `validate.py` fails if any file disagrees
with `updater/updater.lua` about it, so you cannot half-finish the job.

Once you have your own copy, [SETUP.md](SETUP.md) is the whole of publishing a
tool into it.

If you would rather add a tool *here* than run your own, open an issue first
and we can look into it.
