#!/usr/bin/env python3
"""The wired and tethered links, for the network service (services/Network.qml).

    network-links.py

Prints one JSON object: `links`, every NetworkManager profile that isn't
Wi-Fi but carries traffic out (ethernet, USB tethering, Bluetooth
tethering, mobile broadband), and `primary`, the device the default route
with the lowest metric goes through (what the traffic takes).

Each link: { name, uuid, type ("ethernet" | "bluetooth" | "gsm"), kind
("ethernet" | "usb" | "bluetooth" | "mobile"), device, active, available,
title, address }. A USB tether is told by its device's driver (RNDIS,
CDC, Apple's ipheth); its title is the phone's name as the USB device
gives it. `available` is false for a cable profile whose port has no cable
in (or whose device is gone).
"""

import json
import os
import re
import subprocess

ENV = dict(os.environ, LANG="C.UTF-8", LC_ALL="C.UTF-8")
TETHER_DRIVERS = {"rndis_host", "cdc_ether", "cdc_ncm", "ipheth", "cdc_mbim", "qmi_wwan"}
TYPES = {"802-3-ethernet": "ethernet", "bluetooth": "bluetooth", "gsm": "gsm"}


def run(*cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, env=ENV, timeout=5).stdout
    except (OSError, subprocess.SubprocessError):
        return ""


def fields(line):
    """nmcli -t's fields: split on ':' that isn't escaped as '\\:'."""
    out, cur, i = [], "", 0
    while i < len(line):
        c = line[i]
        if c == "\\" and i + 1 < len(line):
            cur += line[i + 1]
            i += 2
            continue
        if c == ":":
            out.append(cur)
            cur = ""
        else:
            cur += c
        i += 1
    out.append(cur)
    return out


def read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return ""


def usb_tether(dev):
    """The phone's name when `dev` is a USB tether, else None."""
    if not dev:
        return None
    base = f"/sys/class/net/{dev}/device"
    driver = os.path.basename(os.path.realpath(base + "/driver")) if os.path.exists(base + "/driver") else ""
    if driver not in TETHER_DRIVERS:
        return None
    # the interface's parent is the USB device itself
    return read(base + "/../product") or read(base + "/../manufacturer") or "Phone"


def main():
    states = {}
    for line in run("nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device").splitlines():
        f = fields(line)
        if len(f) >= 3:
            states[f[0]] = f[2]

    addresses = {}
    try:
        for entry in json.loads(run("ip", "-j", "-4", "addr") or "[]"):
            info = entry.get("addr_info") or []
            if info:
                addresses[entry.get("ifname", "")] = info[0].get("local", "")
    except ValueError:
        pass

    primary = ""
    try:
        routes = json.loads(run("ip", "-j", "route", "show", "default") or "[]")
        routes.sort(key=lambda r: r.get("metric", 0))
        if routes:
            primary = routes[0].get("dev", "")
    except ValueError:
        pass

    links = []
    for line in run("nmcli", "-t", "-f", "NAME,UUID,TYPE,DEVICE,STATE", "connection", "show").splitlines():
        f = fields(line)
        if len(f) < 5 or f[2] not in TYPES:
            continue
        name, uuid, ctype, dev, state = f[0], f[1], TYPES[f[2]], f[3], f[4]
        active = state == "activated"
        kind = {"bluetooth": "bluetooth", "gsm": "mobile"}.get(ctype, "ethernet")
        title = name
        available = True

        if ctype == "ethernet":
            # a profile not up says which port it's for (when it's tied to one)
            port = dev or run("nmcli", "-g", "connection.interface-name", "connection", "show", uuid).strip()
            phone = usb_tether(port)
            if phone:
                kind = "usb"
                title = phone
            elif re.fullmatch(r"Wired connection \d+", name):
                title = "Ethernet"
            if not active:
                available = bool(port) and states.get(port, "unavailable") not in ("unavailable", "unmanaged")
            dev = dev or port
        elif ctype == "bluetooth" and name.endswith(" Network"):
            title = name[: -len(" Network")]

        links.append({
            "name": name,
            "uuid": uuid,
            "type": ctype,
            "kind": kind,
            "device": dev,
            "active": active,
            "available": available,
            "title": title,
            "address": addresses.get(dev, "") if active else "",
        })

    # what's up first, then what could be
    links.sort(key=lambda l: (not l["active"], not l["available"], l["title"].lower()))
    print(json.dumps({"links": links, "primary": primary}))


if __name__ == "__main__":
    main()
