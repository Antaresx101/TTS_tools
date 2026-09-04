"""How the updater block is embedded in a tool file. Standard library only.

Both scripts here work on the same thing - a tool.lua is the script with
updater/updater.lua pasted onto the end and four config values filled in - so
that one operation lives here rather than in two slightly different copies.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UPDATER = ROOT / "updater" / "updater.lua"
TOOLS = ROOT / "tools"

CONFIG_KEYS = ("REPO_BASE", "TOOL_ID", "TOOL_VERSION", "TOOL_SIGNATURE")
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")

DIVIDER = (
    "\n-- ===========================================================================\n"
    "-- Everything below this line is updater/updater.lua, pasted unchanged.\n"
    "-- ===========================================================================\n\n"
)


class BlockError(Exception):
    """Something about the block itself is wrong, and no file was written."""


def canonical():
    return UPDATER.read_text(encoding="utf-8")


def signature_for(tool_id):
    return "TTS-SELFUPDATE:" + tool_id


def write(path, text):
    """Always LF, whatever platform this runs on - these files ship as-is."""
    with open(str(path), "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def literal(text, name):
    """Value of `local NAME = "value"` or `local NAME = 123`."""
    m = re.search(r'^local\s+%s\s*=\s*"([^"]*)"' % name, text, re.M)
    if m:
        return m.group(1)
    m = re.search(r"^local\s+%s\s*=\s*(\d+)" % name, text, re.M)
    return m.group(1) if m else None


def set_config(block, key, value):
    """Rewrite `local KEY = "..."` in a copy of the block."""
    pattern = r'^local\s+%s(\s*)=\s*"[^"]*"([ \t]*--.*)?$' % key
    replacement = lambda m: 'local %s%s= "%s"%s' % (key, m.group(1), value,
                                                    m.group(2) or "")
    block, count = re.subn(pattern, replacement, block, flags=re.M)
    if count != 1:
        raise BlockError("expected one %s line in updater/updater.lua, found %d"
                         % (key, count))
    return block


def block_of(text):
    """The updater block as embedded in a distributable file, or None."""
    opener = canonical().splitlines()[0]
    index = text.find(opener)
    return None if index < 0 else text[index:]


def head_of(text):
    """Everything above the block: the tool's own script, divider and all."""
    opener = canonical().splitlines()[0]
    index = text.find(opener)
    return text if index < 0 else text[:index]


def without_config(text):
    """Blank the four config values so copies compare equal across tools."""
    for key in CONFIG_KEYS:
        text = re.sub(r'^local\s+%s\s*=.*$' % key,
                      "local %s = <config>" % key, text, flags=re.M)
    return text


def stamp(text, tool_id, version):
    """A tool file rebuilt around the current block, config filled in.

    `text` is either a finished tool.lua or a bare object script with no block
    in it yet; both come out the same shape. Rebuilding from the canonical
    block on every pass is the point - a tool folder can never drift, and the
    file stays an ordinary readable one you can diff afterwards.
    """
    head = head_of(text)
    if head == text:                     # no block in there yet
        head = text.rstrip("\n") + "\n" + DIVIDER

    signature = signature_for(tool_id)
    if not head.startswith("-- " + signature):
        head = "-- %s\n--\n%s" % (signature, head)

    block = canonical()
    block = set_config(block, "TOOL_ID", tool_id)
    block = set_config(block, "TOOL_VERSION", version)
    block = set_config(block, "TOOL_SIGNATURE", signature)
    return head + block
