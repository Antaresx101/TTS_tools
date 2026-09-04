"""How the updater block is embedded in a tool file. Standard library only.

Both scripts here work on the same thing - a tool.lua is the script with
updater/updater.lua pasted onto the end and four config values filled in - so
that one operation lives here rather than in two slightly different copies.

A tool may also ship an XML UI as tool.xml beside it. That file carries the
same signature the script does, as an XML comment on its first line, which is
what a client checks a downloaded UI against before it installs anything.
"""

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
UPDATER = ROOT / "updater" / "updater.lua"
TOOLS = ROOT / "tools"

CONFIG_KEYS = ("REPO_BASE", "TOOL_ID", "TOOL_VERSION", "TOOL_SIGNATURE")
SEMVER = re.compile(r"^\d+\.\d+\.\d+$")

# Any signature comment, whoever it names: the stamps strip these before they
# write the right one, so a file copied from another tool - or a folder that
# was renamed - cannot keep a signature that would make clients refuse it, or
# end up carrying two.
XML_SIGNATURE_LINE = re.compile(r"^\s*<!--\s*TTS-SELFUPDATE:[^>]*-->\s*$")
LUA_SIGNATURE_LINE = re.compile(r"^--\s*TTS-SELFUPDATE:\S*\s*$")

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


def xml_comment(tool_id):
    """The signature as it appears in an XML UI: a comment, and nothing else.

    XML has no line comments and nowhere to keep a literal, so the gate a
    client applies to a UI download is this exact string appearing in it.
    """
    return "<!-- %s -->" % signature_for(tool_id)


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
    file stays an ordinary readable one that diffs cleanly afterwards.
    """
    head = head_of(text)
    if head == text:                     # no block in there yet
        head = text.rstrip("\n") + "\n" + DIVIDER

    signature = signature_for(tool_id)
    # Drop a header from a name this tool used to have before writing the one
    # it has now. Renaming a folder is how a file ends up with two of them,
    # and the stale one names a tool that no longer exists.
    lines = head.splitlines(True)
    while lines and LUA_SIGNATURE_LINE.match(lines[0]):
        lines.pop(0)
        if lines and lines[0].strip() == "--":
            lines.pop(0)
    head = "-- %s\n--\n%s" % (signature, "".join(lines))

    block = canonical()
    block = set_config(block, "TOOL_ID", tool_id)
    block = set_config(block, "TOOL_VERSION", version)
    block = set_config(block, "TOOL_SIGNATURE", signature)
    return head + block


def stamp_xml(text, tool_id):
    """An XML UI file with this tool's signature comment as its first line.

    The counterpart to stamp() for the other half of a tool, and the whole of
    preparing a UI for publishing: nothing else in the file is touched, and
    running it twice changes nothing the second time.
    """
    lines = [ln for ln in text.splitlines() if not XML_SIGNATURE_LINE.match(ln)]
    return "\n".join([xml_comment(tool_id)] + lines).rstrip("\n") + "\n"
