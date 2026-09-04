#!/usr/bin/env python3
"""Scaffold new tool folder. Standard library only.

    python scripts/new-tool.py my-tool path/to/my-script.lua

Takes a finished object script, pastes updater/updater.lua onto the end of
it, fills in the three config values from the tool id, and writes both files
into tools/my-tool/. Then it runs validate.py to find out immediately if
anything is off.

A tool with an XML UI passes it as --xml, and the file is copied in as
tool.xml with the tool's signature stamped on its first line and "xml": true
written into the manifest, which is what makes clients fetch it at all.

It never overwrites an existing tool folder, and it never edits the source
script. Everything it produces is an ordinary readable file that can be
opened, diffed and hand-edited afterwards - there is no build step and no
generated bundle.
"""

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path

from block import (ROOT, UPDATER, BlockError, signature_for, stamp, stamp_xml,
                   write)

VALID_ID = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def die(message):
    sys.exit("new-tool: " + message)


def main():
    parser = argparse.ArgumentParser(
        description="Create tools/<tool-id>/ from a finished object script.")
    parser.add_argument("tool_id", help="folder name, lowercase with dashes")
    parser.add_argument("source", type=Path, help="the finished object script")
    parser.add_argument("--xml", type=Path, metavar="PATH",
                        help="the tool's XML UI, if it has one")
    parser.add_argument("--version", default="1.0.0", help="initial version (default 1.0.0)")
    parser.add_argument("--notes", action="append", metavar="LINE",
                        help="one release-note bullet; repeat it for a list")
    args = parser.parse_args()

    tool_id = args.tool_id
    if not VALID_ID.match(tool_id):
        die("%r is not a usable tool id. Use lowercase letters, digits and "
            "single dashes, for example 'turn-timer'." % tool_id)
    if not re.match(r"^\d+\.\d+\.\d+$", args.version):
        die("--version must be plain X.Y.Z, got %r" % args.version)
    if not args.source.is_file():
        die("cannot read %s" % args.source)
    if args.xml and not args.xml.is_file():
        die("cannot read %s" % args.xml)
    if not UPDATER.is_file():
        die("cannot find %s" % UPDATER)

    folder = ROOT / "tools" / tool_id
    if folder.exists():
        die("tools/%s already exists. Delete it by hand if that was the "
            "intention - this script will not overwrite it." % tool_id)

    head = args.source.read_text(encoding="utf-8")
    signature = signature_for(tool_id)

    # Warn loudly, but still write. The block needs no call from the script -
    # it listens for the command by itself - but a payload with no onLoad is
    # one every client refuses, and nothing in game reports why.
    warnings = []
    if "function onLoad" not in head:
        warnings.append("the script has no `function onLoad`, which the payload "
                        "check requires. Clients will reject it.")

    try:
        payload = stamp(head, tool_id, args.version)
    except BlockError as exc:
        die(str(exc))

    folder.mkdir(parents=True)
    lua = folder / "tool.lua"
    manifest = folder / "manifest.json"
    write(lua, payload)

    # "xml": true is what makes a client ask for the UI at all, so the flag and
    # the file are written in one go and cannot come apart here.
    xml = None
    # Notes are always a list, even with one entry: that is the shape that
    # arrives in chat as a bulleted list, and the shape people copy from.
    stable = {"version": args.version, "notes": args.notes or ["First release."]}
    if args.xml:
        xml = folder / "tool.xml"
        write(xml, stamp_xml(args.xml.read_text(encoding="utf-8"), tool_id))
        stable["xml"] = True
    write(manifest, json.dumps({"stable": stable}, indent=2) + "\n")

    print("created tools/%s/" % tool_id)
    print("  tool.lua       %d bytes, TOOL_ID = %r, v%s"
          % (lua.stat().st_size, tool_id, args.version))
    if xml:
        print("  tool.xml       %d bytes, signed for %r"
              % (xml.stat().st_size, tool_id))
    print("  manifest.json  v%s%s" % (args.version, ', "xml": true' if xml else ""))
    for warning in warnings:
        print("\n  WARNING: " + warning)
    print()
    sys.stdout.flush()      # so validate.py's output lands after ours, not before

    result = subprocess.run([sys.executable, str(ROOT / "scripts" / "validate.py")])
    if result.returncode == 0 and not warnings:
        print("\nCommit the folder and push. The tool is live at")
        print("  tools/%s/tool.lua" % tool_id)
        if xml:
            print("  tools/%s/tool.xml" % tool_id)
    return result.returncode


if __name__ == "__main__":
    sys.exit(main())
