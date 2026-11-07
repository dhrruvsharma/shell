#!/usr/bin/env python3
"""A WireGuard config (the .conf a VPN provider gives you) into
NetworkManager, for the VPN pane (services/Vpn.qml).

    vpn-import.py FILE [NAME]

NetworkManager names the tunnel's interface after the file, and turns down
a file whose name isn't a valid interface name (15 characters at most,
which most providers' file names aren't); and it brings an imported tunnel
up straight away. So the file goes in under a short interface name (wg-…),
then the profile is given NAME (the file's name without .conf by default),
is kept from connecting by itself, and is taken down again.

Prints one JSON object: {"ok", "uuid", "name", "error"}.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

ENV = {**os.environ, "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8"}


def run(args):
    try:
        return subprocess.run(args, capture_output=True, text=True, env=ENV, timeout=30)
    except (OSError, subprocess.TimeoutExpired) as e:
        return subprocess.CompletedProcess(args, 1, "", str(e))


def out(obj):
    print(json.dumps(obj), flush=True)


def fail(message):
    out({"ok": False, "uuid": "", "name": "", "error": message})
    sys.exit(0)


def unescape(s):
    return s.replace("\\:", ":").replace("\\\\", "\\")


# Interface names in use: the links there are, and the ones WireGuard
# profiles would make.
def taken_interfaces():
    names = set()
    for line in run(["ip", "-o", "link", "show"]).stdout.splitlines():
        m = re.match(r"\d+:\s+([^:@\s]+)", line)
        if m:
            names.add(m.group(1))
    for line in run(["nmcli", "-g", "UUID,TYPE", "connection", "show"]).stdout.splitlines():
        parts = line.split(":")
        if len(parts) >= 2 and parts[-1] == "wireguard":
            uuid = parts[0]
            name = run(["nmcli", "-g", "connection.interface-name", "connection", "show", "uuid", uuid]).stdout.strip()
            if name:
                names.add(unescape(name))
    return names


def taken_names():
    return {unescape(line) for line in run(["nmcli", "-g", "NAME", "connection", "show"]).stdout.splitlines()}


def interface_for(base, taken):
    stem = re.sub(r"[^a-z0-9_.-]+", "", base.lower()).strip(".-") or "vpn"
    name = ("wg-" + stem)[:15]
    i = 2
    while name in taken:
        tail = str(i)
        name = ("wg-" + stem)[:15 - len(tail)] + tail
        i += 1
    return name


def main(argv):
    if len(argv) < 2:
        fail("usage: vpn-import.py FILE [NAME]")
    path = os.path.expanduser(argv[1])
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read(65536)
    except OSError as e:
        fail("Couldn't read it: %s." % str(e.strerror or e).lower())
    lowered = text.lower()
    if "[interface]" not in lowered or "privatekey" not in lowered or "[peer]" not in lowered:
        fail("That isn't a WireGuard config (it needs an [Interface] with a PrivateKey, and a [Peer]).")

    base = os.path.basename(path)
    base = base[:-5] if base.lower().endswith(".conf") else base
    name = (argv[2].strip() if len(argv) > 2 and argv[2].strip() else base)[:60]
    names = taken_names()
    unique, i = name, 2
    while unique in names:
        unique = "%s %d" % (name, i)
        i += 1

    iface = interface_for(base, taken_interfaces())
    with tempfile.TemporaryDirectory(prefix="vpn-import-") as d:
        os.chmod(d, 0o700)
        copy = os.path.join(d, iface + ".conf")
        # (it holds the private key)
        fd = os.open(copy, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(text)
        r = run(["nmcli", "connection", "import", "type", "wireguard", "file", copy])
    if r.returncode != 0:
        why = (r.stderr.strip() or r.stdout.strip() or "NetworkManager turned it down").replace("Error: ", "")
        why = re.sub(r"failed to import '[^']*': ", "", why)
        fail(why[:1].upper() + why[1:] if why else "NetworkManager turned it down.")
    m = re.search(r"\(([0-9a-f]{8}-[0-9a-f-]{27})\)", r.stdout)
    if not m:
        fail("NetworkManager added it, but didn't say as what.")
    uuid = m.group(1)
    run(["nmcli", "connection", "modify", "uuid", uuid, "connection.id", unique, "connection.autoconnect", "no"])
    run(["nmcli", "connection", "down", "uuid", uuid])
    out({"ok": True, "uuid": uuid, "name": unique, "error": ""})


if __name__ == "__main__":
    main(sys.argv)
