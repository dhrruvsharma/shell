#!/usr/bin/env python3
"""DNS for the DNS panel (services/Dns.qml), through NetworkManager.

  dns-probe.py status               the connection carrying the default route:
                                    the servers in use, the ones set on it and
                                    whether they're encrypted; and whether
                                    NetworkManager can encrypt at all (it can
                                    while it hands DNS to systemd-resolved)
  dns-probe.py resolve HOST         HOST's addresses, by the system's resolver
  dns-probe.py works                whether the system's resolver finds
                                    example.com (a few tries, ~6 s at most)
  dns-probe.py check IP [IP ...]    asks each server for example.com over UDP
                                    port 53, all at once, and a server that
                                    can't exist (192.0.2.53, kept for
                                    documentation) alongside: if that one
                                    answers too, the network intercepts DNS and
                                    no answer means the server was reached
  dns-probe.py tls NAME IP [IP ...] the same over TLS to port 853, each
                                    server's certificate checked against NAME
  dns-probe.py set UUID DEV V4 V6 [NAME]
                                    puts the servers (comma-separated lists) on
                                    the connection in place of the router's and
                                    reapplies it on DEV ("-": doesn't); with
                                    NAME they're encrypted, strictly (no going
                                    back to plain DNS when TLS fails)
  dns-probe.py auto UUID DEV        back to the router's servers, unencrypted

Each prints one JSON object.
"""
import json
import os
import random
import socket
import ssl
import struct
import subprocess
import sys
import threading
import time

ENV = {**os.environ, "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8"}
DECOY = "192.0.2.53"
TLS_SETTING = {"-1": "default", "0": "no", "1": "opportunistic", "2": "yes"}


def out(obj):
    print(json.dumps(obj), flush=True)


def run(args):
    try:
        return subprocess.run(args, capture_output=True, text=True, env=ENV, timeout=25)
    except (OSError, subprocess.TimeoutExpired) as e:
        return subprocess.CompletedProcess(args, 1, "", str(e))


def unescape(s):
    # nmcli -g escapes ':' and '\' in values.
    return s.replace("\\:", ":").replace("\\\\", "\\")


def split_list(s, sep):
    return [unescape(x.strip()) for x in s.split(sep) if x.strip()]


def server_entry(s):
    """"94.140.14.14#dns.adguard-dns.com", "[2a10::1]:853#name" → {ip, name}."""
    ip, _, name = s.partition("#")
    ip = ip.strip()
    if ip.startswith("["):
        ip = ip[1:ip.find("]")] if "]" in ip else ip[1:]
    elif ip.count(":") == 1:
        ip = ip.split(":")[0]  # an IPv4 address with a port
    if "%" in ip:
        ip = ip.split("%")[0]  # a scope
    return {"ip": ip, "name": name.strip()}


def default_device():
    for fam in (["-4"], ["-6"]):
        r = run(["ip", "-j"] + fam + ["route", "show", "default"])
        try:
            routes = json.loads(r.stdout or "[]")
        except ValueError:
            routes = []
        for route in routes:
            if route.get("dev"):
                return route["dev"]
    return ""


def dns_mode():
    r = run(["busctl", "--system", "get-property", "org.freedesktop.NetworkManager",
             "/org/freedesktop/NetworkManager/DnsManager",
             "org.freedesktop.NetworkManager.DnsManager", "Mode"])
    text = r.stdout.strip()
    return text.split('"')[1] if text.count('"') >= 2 else ""


def status():
    mode = dns_mode()
    res = {"device": "", "connection": "", "uuid": "", "servers": [], "configured": [],
           "own": False, "tls": "default", "mode": mode, "canTls": mode == "systemd-resolved",
           "error": ""}
    dev = default_device()
    if not dev:
        res["error"] = "Not connected"
        return res
    res["device"] = dev
    r = run(["nmcli", "-g", "GENERAL.CONNECTION,GENERAL.CON-UUID,IP4.DNS,IP6.DNS", "device", "show", dev])
    lines = r.stdout.split("\n") + ["", "", "", ""]
    res["connection"] = unescape(lines[0].strip())
    res["uuid"] = unescape(lines[1].strip())
    res["servers"] = [server_entry(x)["ip"] for x in split_list(lines[2], "|") + split_list(lines[3], "|")]
    if not res["uuid"]:
        res["error"] = "%s isn't NetworkManager's" % dev
        return res
    c = run(["nmcli", "-g", "ipv4.dns,ipv4.ignore-auto-dns,ipv6.dns,ipv6.ignore-auto-dns,connection.dns-over-tls",
             "connection", "show", "uuid", res["uuid"]])
    f = c.stdout.split("\n") + ["", "", "", "", ""]
    configured = [server_entry(x) for x in split_list(f[0], ",") + split_list(f[2], ",")]
    res["configured"] = configured
    res["own"] = f[1].strip() == "yes" and len(configured) > 0
    res["tls"] = TLS_SETTING.get(f[4].strip(), f[4].strip() or "default")
    return res


def lookup(host, timeout=5.0):
    """getaddrinfo with a deadline: ({"v4": [...], "v6": [...]}, error)."""
    found = {"v4": [], "v6": []}
    err = []

    def work():
        try:
            for fam, _, _, _, addr in socket.getaddrinfo(host, 53, proto=socket.IPPROTO_UDP):
                key = "v6" if fam == socket.AF_INET6 else "v4"
                if addr[0] not in found[key]:
                    found[key].append(addr[0])
        except socket.gaierror as e:
            err.append({socket.EAI_NONAME: "there's no such name",
                        socket.EAI_AGAIN: "the lookup failed"}.get(e.errno, (e.strerror or str(e)).lower()))
        except OSError as e:
            err.append((e.strerror or str(e)).lower())

    t = threading.Thread(target=work, daemon=True)
    t.start()
    t.join(timeout)
    if t.is_alive():
        err.append("the lookup timed out")
    return found, (err[0] if err and not (found["v4"] or found["v6"]) else "")


def resolve(host):
    found, err = lookup(host)
    return {"host": host, "v4": found["v4"], "v6": found["v6"], "error": err}


def works():
    t0 = time.monotonic()
    err = ""
    for attempt in range(3):
        found, err = lookup("example.com", 3.0 if attempt < 2 else 2.0)
        if found["v4"] or found["v6"]:
            return {"ok": True, "ms": round((time.monotonic() - t0) * 1000), "error": ""}
        if time.monotonic() - t0 > 6:
            break
        time.sleep(0.4)
    return {"ok": False, "ms": -1, "error": err or "lookups fail"}


def query(name="example.com"):
    qid = random.randint(0, 0xFFFF)
    packet = struct.pack(">HHHHHH", qid, 0x0100, 1, 0, 0, 0)
    packet += b"".join(bytes([len(p)]) + p.encode() for p in name.split(".")) + b"\0"
    packet += struct.pack(">HH", 1, 1)
    return qid, packet


def rcode_error(data):
    rcode = data[3] & 0x0F
    # (3: no such name, an answer all the same)
    return "" if rcode in (0, 3) else "it answered with an error (code %d)" % rcode


def ask(server, timeout=2.5):
    """One question over UDP port 53: {server, answered, ok, ms, error}."""
    qid, packet = query()
    fam = socket.AF_INET6 if ":" in server else socket.AF_INET
    res = {"server": server, "answered": False, "ok": False, "ms": -1, "error": ""}
    t0 = time.monotonic()
    try:
        s = socket.socket(fam, socket.SOCK_DGRAM)
    except OSError as e:
        res["error"] = (e.strerror or str(e)).lower()
        return res
    s.settimeout(timeout)
    try:
        s.sendto(packet, (server, 53))
        while True:
            data, _ = s.recvfrom(4096)
            if len(data) >= 12 and struct.unpack(">H", data[:2])[0] == qid:
                break
        res["answered"] = True
        res["ms"] = round((time.monotonic() - t0) * 1000)
        res["error"] = rcode_error(data)
        res["ok"] = res["error"] == ""
    except socket.timeout:
        res["error"] = "no answer"
    except OSError as e:
        res["error"] = (e.strerror or str(e)).lower()
    finally:
        s.close()
    return res


def ask_tls(server, name, timeout=5.0):
    """One question over TLS to port 853, the certificate checked against
    `name`: {server, ok, ms, error}."""
    res = {"server": server, "ok": False, "ms": -1, "error": ""}
    qid, packet = query()
    ctx = ssl.create_default_context()
    t0 = time.monotonic()
    try:
        with socket.create_connection((server, 853), timeout=timeout) as raw:
            raw.settimeout(max(0.5, timeout - (time.monotonic() - t0)))
            with ctx.wrap_socket(raw, server_hostname=name) as s:
                s.sendall(struct.pack(">H", len(packet)) + packet)
                head = b""
                while len(head) < 2:
                    chunk = s.recv(2 - len(head))
                    if not chunk:
                        raise ConnectionResetError("closed")
                    head += chunk
                size = struct.unpack(">H", head)[0]
                data = b""
                while len(data) < size:
                    chunk = s.recv(size - len(data))
                    if not chunk:
                        raise ConnectionResetError("closed")
                    data += chunk
        res["ms"] = round((time.monotonic() - t0) * 1000)
        if len(data) < 12 or struct.unpack(">H", data[:2])[0] != qid:
            res["error"] = "its answer made no sense"
        else:
            res["error"] = rcode_error(data)
        res["ok"] = res["error"] == ""
    except ssl.SSLCertVerificationError as e:
        mismatch = getattr(e, "verify_code", 0) == 62 or "mismatch" in str(e).lower()
        res["error"] = ("its certificate isn't for %s" % name) if mismatch else "its certificate couldn't be verified"
    except socket.timeout:
        res["error"] = "no answer on port 853"
    except ConnectionRefusedError:
        res["error"] = "it turned the connection down"
    except ConnectionResetError:
        res["error"] = "it hung up"
    except ssl.SSLError:
        res["error"] = "the TLS handshake failed"
    except OSError as e:
        res["error"] = (e.strerror or str(e)).lower()
    return res


def all_at_once(fn, items, wait):
    results = [None] * len(items)

    def one(i, item):
        results[i] = fn(item)

    threads = [threading.Thread(target=one, args=(i, it), daemon=True) for i, it in enumerate(items)]
    for t in threads:
        t.start()
    deadline = time.monotonic() + wait
    for t in threads:
        t.join(max(0, deadline - time.monotonic()))
    return results


def check(servers):
    results = all_at_once(lambda s: ask(s, 1.5 if s == DECOY else 2.5), servers + [DECOY], 4)
    decoy = results.pop()
    results = [r or {"server": servers[i], "answered": False, "ok": False, "ms": -1, "error": "no answer"}
               for i, r in enumerate(results)]
    return {"results": results, "ok": any(r["ok"] for r in results),
            "intercepted": bool(decoy and decoy["answered"])}


def check_tls(name, servers):
    results = all_at_once(lambda s: ask_tls(s, name), servers, 7)
    results = [r or {"server": servers[i], "ok": False, "ms": -1, "error": "no answer on port 853"}
               for i, r in enumerate(results)]
    return {"name": name, "results": results, "ok": any(r["ok"] for r in results)}


def reapply(uuid, dev):
    if dev in ("", "-"):
        return ""
    r = run(["nmcli", "device", "reapply", dev])
    if r.returncode == 0:
        return ""
    r = run(["nmcli", "connection", "up", "uuid", uuid])
    return "" if r.returncode == 0 else (r.stderr.strip().replace("Error: ", "") or "NetworkManager couldn't bring it back up")


def modify(uuid, props):
    r = run(["nmcli", "connection", "modify", "uuid", uuid] + props)
    return "" if r.returncode == 0 else (r.stderr.strip().replace("Error: ", "") or "NetworkManager refused the change")


def set_servers(uuid, dev, v4, v6, name):
    def entries(ips):
        return " ".join(ip + ("#" + name if name else "") for ip in ips)

    props4 = ["ipv4.dns", entries(v4), "ipv4.ignore-auto-dns", "yes"]
    props6 = ["ipv6.dns", entries(v6), "ipv6.ignore-auto-dns", "yes"]
    tls = ["connection.dns-over-tls", "yes" if name else "default"]
    err = modify(uuid, props4 + props6 + tls)
    if err and not v6:
        # (IPv6 switched off on this connection: its DNS can't be touched)
        err = modify(uuid, props4 + tls)
    if err:
        return {"ok": False, "error": err}
    err = reapply(uuid, dev)
    return {"ok": not err, "error": err}


def automatic(uuid, dev):
    props4 = ["ipv4.dns", "", "ipv4.ignore-auto-dns", "no"]
    props6 = ["ipv6.dns", "", "ipv6.ignore-auto-dns", "no"]
    tls = ["connection.dns-over-tls", "default"]
    err = modify(uuid, props4 + props6 + tls)
    if err:
        err = modify(uuid, props4 + tls)
    if err:
        return {"ok": False, "error": err}
    err = reapply(uuid, dev)
    return {"ok": not err, "error": err}


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "status"
    args = argv[2:]
    if cmd == "status":
        out(status())
    elif cmd == "resolve" and args:
        out(resolve(args[0]))
    elif cmd == "works":
        out(works())
    elif cmd == "check" and args:
        out(check(args))
    elif cmd == "tls" and len(args) > 1:
        out(check_tls(args[0], args[1:]))
    elif cmd == "set" and len(args) >= 4:
        out(set_servers(args[0], args[1], split_list(args[2], ","), split_list(args[3], ","),
                        args[4].strip() if len(args) > 4 else ""))
    elif cmd == "auto" and len(args) >= 2:
        out(automatic(args[0], args[1]))
    else:
        out({"ok": False, "error": "usage: dns-probe.py status | resolve HOST | works | check IP... | "
                                   "tls NAME IP... | set UUID DEV V4 V6 [NAME] | auto UUID DEV"})


if __name__ == "__main__":
    main(sys.argv)
