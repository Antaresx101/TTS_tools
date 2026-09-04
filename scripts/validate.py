#!/usr/bin/env python3
"""Repo consistency check. Standard library only; run before push.

    python scripts/validate.py          check everything, change nothing
    python scripts/validate.py --fix    put right what can be put right, then check

Every tool folder is checked against the rules the updater block relies on at
runtime. The one that bites hardest is version drift: if manifest.json says
1.2.0 while tool.lua still says TOOL_VERSION = "1.1.0", every client downloads
the payload on every single load, forever, and throws it away at the last gate.
Nothing in game reports that. This does.

--fix is the drop-in path: put a folder under tools/ holding the object script
as tool.lua and a manifest.json beside it, run it, and the folder is a
publishable tool. It pastes updater/updater.lua onto the end of the script,
fills the config in from the folder name and the manifest, and re-pastes the
block over any copy that has drifted. It never touches the code above the
block, and it never decides a version: the manifest says what is
published, and tool.lua is made to agree with it.
"""

import argparse
import difflib
import json
import re
import sys

from block import (ROOT, SEMVER, TOOLS, UPDATER, BlockError, block_of,
                   canonical, literal, signature_for, stamp, without_config,
                   write)

# Release notes land in everyone's chat window at once, so they are held to a
# size. None of these are enforced in game - the block prints whatever it is
# given - which is exactly why the checks belong here, before the push.
# MAX_CATCHUP bounds the worst case: the oldest copy still out there wakes up
# and is told about every release it missed, all in one message.
# The only three lines in the block allowed to say "Global." at all: read
# the latch, write it, and drop the last asking's answer when a check starts.
GLOBAL_CALLS = (
    "Global.getVar(key)",
    "Global.setVar(key, value)",
    'Global.setVar(GLOBAL_KEY .. "_ANSWER", "")',
)

MAX_NOTES = 6
MAX_NOTE_CHARS = 160
MAX_CATCHUP = 24

problems = []


def fail(where, message, detail=None):
    problems.append((where, message, detail))


def rank(version):
    """Comparable form of a plain X.Y.Z, matching what the block does."""
    return tuple(int(part) for part in version.split("."))


def check_one_write(where, text):
    """The whole safety story in one line: one script write, and it is on self.

    Docs tell a suspicious mod author to grep for this. The grep is only worth
    trusting if something enforces it, so this does.
    """
    writes = [(n, ln.strip()) for n, ln in enumerate(text.splitlines(), 1)
              if "setLuaScript" in ln]
    if len(writes) != 1:
        fail(where, "expected exactly 1 script write, found %d" % len(writes),
             "\n".join("  line %d: %s" % w for w in writes))
    elif not re.search(r"\bself\.setLuaScript\s*\(", writes[0][1]):
        fail(where, "the script write does not target self",
             "  line %d: %s" % writes[0])

    # Global is touched for one thing: the latch that stops three copies of a
    # tool saying the same thing three times. Docs tell a suspicious mod author
    # to grep for it, so these are the only three lines that grep may find.
    block = block_of(text) or text
    uses = [ln.strip() for ln in block.splitlines()
            if "Global." in ln and not ln.strip().startswith("--")]
    stray = [u for u in uses if not any(a in u for a in GLOBAL_CALLS)]
    if stray or len(uses) > len(GLOBAL_CALLS):
        fail(where, "Global is only ever reached by the announce latch, on a "
                    "key built from the tool id",
             "\n".join("  " + u for u in uses))


def check_switch(where, text):
    """SELF_UPDATE is the one opt-out, and it ships as true.

    A published file with it set to false would install a dead updater on
    everyone who takes the update, and nothing in game would say why.
    """
    if not re.search(r"^local\s+SELF_UPDATE\s*=\s*true\b", text, re.M):
        fail(where, "SELF_UPDATE is not `true`, so every copy of this file "
                    "would stop updating for good",
             "  it is the switch a player flips in their own copy, never here")


def check_block_matches(where, text, canonical):
    embedded = block_of(text)
    if embedded is None:
        return fail(where, "carries no updater block (searched for its header)")
    mine = without_config(embedded).splitlines()
    theirs = without_config(canonical).splitlines()
    if mine != theirs:
        diff = list(difflib.unified_diff(theirs, mine, "updater/updater.lua",
                                         str(where), lineterm="", n=1))
        fail(where, "embedded block has drifted from updater/updater.lua",
             "\n".join("  " + d for d in diff[:24]))


def as_list(notes):
    """A notes field as the list of bullets it renders to, same as the block."""
    if isinstance(notes, str):
        return [notes]
    return notes if isinstance(notes, list) else []


def check_notes(where, entry):
    """Release notes: one string, or a list of them, one bullet per entry.

    A version with nothing to say about itself still updates fine, so this is
    the only rule here that is a house style rather than a runtime concern -
    the point of the whole feature is that players are told what changed.
    """
    notes = entry.get("notes")
    if isinstance(notes, str):
        notes = [notes]
    if notes is None:
        return fail(where, "no release notes, so an update announces a bare "
                           "version number and nothing else",
                    '  add "notes": ["what changed"] beside the version')
    if not isinstance(notes, list) or not all(isinstance(n, str) for n in notes):
        return fail(where, 'notes must be a string, or a list of strings for a '
                           'bulleted list')
    if not notes or any(not n.strip() for n in notes):
        return fail(where, "empty release note")
    if len(notes) > MAX_NOTES:
        fail(where, "%d release notes; more than %d fills the chat window on "
                    "every client at once" % (len(notes), MAX_NOTES))
    long = [n for n in notes if len(n) > MAX_NOTE_CHARS]
    if long:
        fail(where, "release note over %d characters, which wraps badly in TTS "
                    "chat" % MAX_NOTE_CHARS,
             "\n".join("  %s..." % n[:60] for n in long))
    return None


def check_history(where, manifest, current):
    """Past releases, newest first, every one of them older than the current.

    Optional: a tool with no history simply announces the release it is on.
    With one, a copy that skipped versions is caught up on all of them, so
    the order here is the order players read - the block trusts this list
    rather than sorting it.
    """
    history = manifest.get("history")
    if history is None:
        return None
    if not isinstance(history, list) or not all(isinstance(h, dict) for h in history):
        return fail(where, '"history" must be a list of past releases, each '
                           'shaped like the "stable" entry')

    ranks = []
    for entry in history:
        version = entry.get("version")
        if not isinstance(version, str) or not SEMVER.match(version):
            fail(where, "history version %r is not plain X.Y.Z, so the block "
                        "sorts it below everything" % (version,))
            continue
        ranks.append((rank(version), version))
        check_notes(where, entry)

    ordered = [r for r, _ in ranks]
    if ordered != sorted(set(ordered), reverse=True):
        fail(where, "history must run newest first with no repeats",
             "  found: " + ", ".join(v for _, v in ranks))
    stale = [v for r, v in ranks if r >= rank(current)]
    if stale:
        fail(where, "history holds v%s, which is not older than the published "
                    "v%s. Move the outgoing release into history when you bump, "
                    "not the incoming one." % (stale[0], current))

    total = sum(len(as_list(e.get("notes"))) for e in [manifest["stable"]] + history)
    if total > MAX_CATCHUP:
        fail(where, "%d notes across every published release; a copy old enough "
                    "to have missed all of them would be shown the lot in one "
                    "chat message. Trim the tail of history - nobody needs the "
                    "v1.0.1 line two years on." % total)
    return None


def check_payload(where, path, published, tool_id, repo_base, canonical):
    """A tool's tool.lua against the version its manifest publishes."""
    text = path.read_text(encoding="utf-8")

    declared = literal(text, "TOOL_VERSION")
    if declared != published:
        fail(where, "version drift, so every client re-downloads on every load",
             "  manifest.json  version      = %r\n"
             "  %-14s TOOL_VERSION = %r" % (published, path.name, declared))

    if literal(text, "TOOL_ID") != tool_id:
        fail(where, "TOOL_ID does not match the folder name, so this tool would "
                    "fetch someone else's payload",
             "  folder = %r, TOOL_ID = %r" % (tool_id, literal(text, "TOOL_ID")))

    signature = literal(text, "TOOL_SIGNATURE")
    if not signature:
        fail(where, "no TOOL_SIGNATURE literal")
    elif signature not in text:
        fail(where, "does not contain its own signature %r" % signature)

    minimum = int(literal(text, "MIN_BYTES") or 0)
    size = len(text.encode("utf-8"))
    if size <= minimum:
        fail(where, "%d bytes, at or under its own MIN_BYTES gate of %d, so "
                    "clients would reject it" % (size, minimum))

    if literal(text, "REPO_BASE") != repo_base:
        fail(where, "REPO_BASE differs from updater/updater.lua, so this file "
                    "updates from a different repository",
             "  updater/updater.lua = %r\n  %-19s = %r"
             % (repo_base, path.name, literal(text, "REPO_BASE")))

    check_block_matches(where, text, canonical)
    check_one_write(where, text)
    check_switch(where, text)


def repair(folder):
    """Make one tool folder publishable, in place. Returns what it changed.

    Only ever rewrites the block and the four config values, and only ever
    downwards from the manifest: if tool.lua claims a version the manifest does
    not publish, that is a decision, not a typo, so it is reported instead.
    """
    tool_id, changed = folder.name, []
    manifest_path, lua = folder / "manifest.json", folder / "tool.lua"
    if not lua.exists():
        return changed                   # nothing to build on; the checks say so

    if not manifest_path.exists():
        write(manifest_path, json.dumps(
            {"stable": {"version": "1.0.0", "notes": ["First release."]}},
            indent=2) + "\n")
        changed.append("wrote manifest.json at 1.0.0 - put real notes in it "
                       "before you push")

    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        published = manifest["stable"]["version"]
    except (ValueError, KeyError, TypeError):
        return changed                   # unreadable; check_tool reports it properly
    if not isinstance(published, str) or not SEMVER.match(published):
        return changed

    text = lua.read_text(encoding="utf-8")
    declared = literal(text, "TOOL_VERSION")
    if declared and SEMVER.match(declared) and rank(declared) > rank(published):
        fail("tools/%s" % tool_id,
             "tool.lua declares v%s but manifest.json publishes v%s, so --fix "
             "left both alone" % (declared, published),
             "  bump the manifest to release it, or lower TOOL_VERSION - only "
             "you know which")
        return changed

    embedded = block_of(text)
    if embedded is None:
        changed.append("pasted updater/updater.lua onto the end of your script")
    elif without_config(embedded) != without_config(canonical()):
        changed.append("re-pasted updater/updater.lua over a drifted copy")
    if declared != published:
        changed.append("TOOL_VERSION %s -> %s, from manifest.json"
                       % (declared, published))
    if (literal(text, "TOOL_ID") != tool_id
            or literal(text, "TOOL_SIGNATURE") != signature_for(tool_id)):
        changed.append("set TOOL_ID and TOOL_SIGNATURE from the folder name")
    if literal(text, "REPO_BASE") != literal(canonical(), "REPO_BASE"):
        changed.append("set REPO_BASE from updater/updater.lua")

    try:
        fixed = stamp(text, tool_id, published)
    except BlockError as exc:
        fail("tools/%s/tool.lua" % tool_id, str(exc))
        return changed
    if fixed != text:
        write(lua, fixed)
        if not changed:                  # whitespace, ordering, anything else
            changed.append("rewrote tool.lua around the current block")
    return changed


def repair_example(path):
    """The same treatment for updater/example-tool.lua, which has no manifest.

    It is the file people copy as a starting shape, so it must not be left
    pointing at the repo it was forked from.
    """
    text = path.read_text(encoding="utf-8")
    version = literal(text, "TOOL_VERSION") or "1.0.0"
    try:
        fixed = stamp(text, "example-tool", version)
    except BlockError as exc:
        return fail("updater/example-tool.lua", str(exc)) or []
    if fixed == text:
        return []
    write(path, fixed)
    return ["re-pasted updater/updater.lua and filled in the config"]


def check_tool(folder, canonical, repo_base):
    name = folder.name
    where = "tools/%s" % name
    manifest_path = folder / "manifest.json"

    if not manifest_path.exists():
        return fail(where, "missing manifest.json")
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    except ValueError as exc:
        return fail(where, "manifest.json does not parse: %s" % exc)
    if not isinstance(manifest, dict):
        return fail(where, 'manifest.json must be an object with a "stable" entry')

    entry = manifest.get("stable")
    if not isinstance(entry, dict) or not entry.get("version"):
        return fail(where, 'manifest.json needs {"stable": {"version": "..."}}')

    version = entry["version"]
    if not SEMVER.match(version):
        return fail(where, "version %r is not plain X.Y.Z, which is all the "
                           "block compares" % version)

    check_notes("%s/manifest.json" % where, entry)
    check_history("%s/manifest.json" % where, manifest, version)

    lua = folder / "tool.lua"
    if not lua.exists():
        return fail(where, "manifest.json publishes v%s, but tool.lua is missing"
                           % version)

    check_payload("%s/tool.lua" % where, lua, version, name, repo_base, canonical)
    return None


def main():
    parser = argparse.ArgumentParser(
        description="Check every tool folder against what the block needs at "
                    "runtime.")
    parser.add_argument("--fix", action="store_true",
                        help="first paste in the current block and fill the "
                             "config from the folder name and manifest, so a "
                             "folder you dropped into tools/ becomes a "
                             "publishable tool")
    args = parser.parse_args()

    if not UPDATER.exists():
        print("cannot find %s" % UPDATER)
        return 2

    canon = canonical()
    repo_base = literal(canon, "REPO_BASE")
    check_one_write("updater/updater.lua", canon)
    check_switch("updater/updater.lua", canon)

    example = ROOT / "updater" / "example-tool.lua"
    folders = sorted(p for p in TOOLS.iterdir() if p.is_dir()) if TOOLS.is_dir() else []

    if args.fix:
        done = [("tools/" + f.name, line) for f in folders for line in repair(f)]
        if example.exists():
            done += [("updater/example-tool.lua", line)
                     for line in repair_example(example)]
        for where, line in done:
            print("%s: %s" % (where, line))
        if done:
            print()

    if example.exists():
        text = example.read_text(encoding="utf-8")
        check_block_matches("updater/example-tool.lua", text, canon)
        check_one_write("updater/example-tool.lua", text)
        check_switch("updater/example-tool.lua", text)
        if literal(text, "REPO_BASE") != repo_base:
            fail("updater/example-tool.lua",
                 "REPO_BASE differs from updater/updater.lua, so the file "
                 "people copy as a starting shape points at another repository",
                 "  run: python scripts/validate.py --fix")

    for folder in folders:
        check_tool(folder, canon, repo_base)

    if problems:
        print("FAILED %d check(s)\n" % len(problems))
        for where, message, detail in problems:
            print("  %s: %s" % (where, message))
            if detail:
                print(detail)
            print()
        return 1

    print("OK  %d tool(s): %s" % (len(folders), ", ".join(f.name for f in folders) or "none"))
    print("    block, signature, sizes, versions and notes all consistent")
    return 0


if __name__ == "__main__":
    sys.exit(main())
