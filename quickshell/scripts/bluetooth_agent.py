#!/usr/bin/env python3
"""BlueZ pairing agent for the Bluetooth tab (services/Bluetooth.qml).

Quickshell's Bluetooth module pairs and connects but registers no
org.bluez.Agent1. With no agent, bluetoothd refuses every pairing that needs
a PIN, a passkey or a yes/no, stops accepting pairing requests at all, and
turns away the connections an untrusted device makes by itself
("Authentication attempt without agent"): the things that used to need
blueman. This process is that agent. It registers as the default and hands
every question to the panel. It also runs Pair and Connect itself, so
bluetoothd asks this agent about those pairings even when another one is the
default, and so the panel hears why they failed.

One JSON object per line. Events, on stdout:
  {"event": "ready"}               registered with bluetoothd
  {"event": "down"}                bluetoothd went away (re-registers on return)
  {"event": "request", "id": 3, "kind": "confirm", "device": "/org/bluez/…"}
      kind  confirm       does the device show "passkey"?
            authorize     the device wants to pair
            service       an untrusted device wants service "uuid"
            pin           type the device's PIN here
            passkey       type the passkey the device shows here
            show-pin      type "pincode" on the device
            show-passkey  type "passkey" on the device; "entered" counts the
                          digits typed so far, re-sent under the same id
  {"event": "cancel", "id": 3}     the request is over, drop it
  {"event": "result", "op": "pair" | "connect", "device": …, "ok": false,
   "error": "…"}                   error is "" when there's nothing to say
Commands, on stdin:
  {"cmd": "reply", "id": 3, "accept": true, "value": "0000", "always": false}
      answer a request (accept false refuses it, or dismisses a show-*);
      "always" on a service request also trusts the device
  {"cmd": "pair", "device": …}     Pair, trust, then Connect
  {"cmd": "connect", "device": …}
  {"cmd": "cancel", "device": …}   CancelPairing
Runs until stdin closes.
"""

import json
import os
import sys
import time

try:
    import gi

    gi.require_version("Gio", "2.0")
    from gi.repository import Gio, GLib
except (ImportError, ValueError) as err:
    print(f"needs PyGObject (python-gobject): {err}", file=sys.stderr)
    sys.exit(2)  # services/Bluetooth.qml doesn't restart on 2

BLUEZ = "org.bluez"
AGENT_PATH = "/org/quickshell/BluetoothAgent"
AGENT_MANAGER = "org.bluez.AgentManager1"
DEVICE = "org.bluez.Device1"
PROPERTIES = "org.freedesktop.DBus.Properties"
REJECTED = "org.bluez.Error.Rejected"
CANCELED = "org.bluez.Error.Canceled"

# Seconds a device's service requests get answered without asking, after the
# user paired with or connected to it here (it is setting up that
# connection), allowed one (the rest belong to the same connection), or
# refused one (so one "no" isn't followed by five more prompts).
GRACE_CONNECT = 20
GRACE_ALLOW = 30
GRACE_DENY = 10
# D-Bus timeouts. bluetoothd gives the user 60 s per question, and pairing
# may ask more than one.
PAIR_TIMEOUT = 150
CONNECT_TIMEOUT = 60
# bluetoothd sends no Cancel once a code it asked us to show is typed, so a
# show-* also ends when the device pairs or drops, or after this long.
SHOW_TIMEOUT = 60

AGENT_XML = """
<node>
  <interface name="org.bluez.Agent1">
    <method name="Release"/>
    <method name="RequestPinCode">
      <arg name="device" type="o" direction="in"/>
      <arg name="pincode" type="s" direction="out"/>
    </method>
    <method name="DisplayPinCode">
      <arg name="device" type="o" direction="in"/>
      <arg name="pincode" type="s" direction="in"/>
    </method>
    <method name="RequestPasskey">
      <arg name="device" type="o" direction="in"/>
      <arg name="passkey" type="u" direction="out"/>
    </method>
    <method name="DisplayPasskey">
      <arg name="device" type="o" direction="in"/>
      <arg name="passkey" type="u" direction="in"/>
      <arg name="entered" type="q" direction="in"/>
    </method>
    <method name="RequestConfirmation">
      <arg name="device" type="o" direction="in"/>
      <arg name="passkey" type="u" direction="in"/>
    </method>
    <method name="RequestAuthorization">
      <arg name="device" type="o" direction="in"/>
    </method>
    <method name="AuthorizeService">
      <arg name="device" type="o" direction="in"/>
      <arg name="uuid" type="s" direction="in"/>
    </method>
    <method name="Cancel"/>
  </interface>
</node>
"""

NOTHING_TO_CONNECT = "Nothing on it to connect to"
# BlueZ's errors, short enough for the device row.
ERRORS = {
    "org.bluez.Error.AuthenticationFailed": "Pairing failed",
    "org.bluez.Error.AuthenticationCanceled": "Pairing was cancelled",
    "org.bluez.Error.AuthenticationRejected": "The device refused to pair",
    "org.bluez.Error.AuthenticationTimeout": "Pairing timed out",
    "org.bluez.Error.ConnectionAttemptFailed": "No answer, is it in pairing mode?",
    "org.bluez.Error.InProgress": "Already in progress",
    "org.bluez.Error.NotReady": "Bluetooth isn't ready",
    "org.bluez.Error.DoesNotExist": "The device is gone",
    "org.bluez.Error.Blocked": "The device is blocked",
    "org.bluez.Error.BREDR.ProfileUnavailable": NOTHING_TO_CONNECT,
    "org.freedesktop.DBus.Error.NoReply": "Timed out",
}
# ...and the br-/le-connection-* reasons bluetoothd gives Connect failures.
REASONS = (
    ("page-timeout", "No answer, is it on and nearby?"),
    ("profile-unavailable", NOTHING_TO_CONNECT),
    ("key-missing", "Pairing lost, remove it and pair again"),
    ("refused", "The device refused"),
    ("by-remote", "The device hung up"),
    ("busy", "Bluetooth is busy, try again"),
    ("not-powered", "Bluetooth is off"),
    ("canceled", "Cancelled"),
    ("timeout", "Timed out"),
)


def emit(event, **fields):
    try:
        sys.stdout.write(json.dumps({"event": event, **fields}) + "\n")
        sys.stdout.flush()
    except BrokenPipeError:
        os._exit(0)  # Quickshell is gone


def log(text):
    print(text, file=sys.stderr, flush=True)


def split_error(err):
    """(D-Bus error name, message) of a failed call."""
    name = Gio.DBusError.get_remote_error(err) or ""
    message = err.message
    if message.startswith("GDBus.Error:"):
        message = message.partition(": ")[2]
    if not name and err.matches(Gio.io_error_quark(), Gio.IOErrorEnum.TIMED_OUT):
        name = "org.freedesktop.DBus.Error.NoReply"
    return name, message


def describe(name, message):
    if name in ERRORS:
        return ERRORS[name]
    for needle, text in REASONS:
        if needle in message:
            return text
    return message or name.rpartition(".")[2] or "Something went wrong"


class Agent:
    def __init__(self, bus, quit):
        self.bus = bus
        self.quit = quit
        self.owner = None  # bluetoothd's unique name while it runs
        self.next_id = 1
        self.asking = {}  # id -> (invocation, kind, device)
        self.showing = {}  # device -> id of its show-* request
        self.grace = {}  # device -> (allow?, until)
        self.quiet = set()  # devices whose pairing the user stopped
        self.buffer = b""

        info = Gio.DBusNodeInfo.new_for_xml(AGENT_XML)
        # GLib 2.84 deprecated register_object for this variant.
        register = getattr(bus, "register_object_with_closures2", bus.register_object)
        register(AGENT_PATH, info.interfaces[0], self.on_call, None, None)
        bus.signal_subscribe(
            None, PROPERTIES, "PropertiesChanged", None, DEVICE,
            Gio.DBusSignalFlags.NONE, self.on_properties,
        )
        Gio.bus_watch_name_on_connection(
            bus, BLUEZ, Gio.BusNameWatcherFlags.NONE, self.on_bluez_up, self.on_bluez_down,
        )
        GLib.io_add_watch(
            sys.stdin.fileno(), GLib.PRIORITY_DEFAULT,
            GLib.IOCondition.IN | GLib.IOCondition.HUP | GLib.IOCondition.ERR,
            self.on_stdin,
        )

    # ── bluetoothd ────────────────────────────────────────────────────────

    def call(self, path, interface, method, args=None, timeout=10, done=None):
        """Call bluetoothd; done(None) on success, done((name, message)) on failure."""

        def finish(bus, result):
            try:
                bus.call_finish(result)
            except GLib.Error as err:
                failure = split_error(err)
            else:
                failure = None
            if done:
                done(failure)
            elif failure:
                log(f"{method} {path}: {failure[0]}: {failure[1]}")

        self.bus.call(
            BLUEZ, path, interface, method, args, None,
            Gio.DBusCallFlags.NONE, timeout * 1000, None, finish,
        )

    def on_bluez_up(self, _bus, _name, owner):
        self.owner = owner

        def registered(failure):
            if failure and failure[0] != "org.bluez.Error.AlreadyExists":
                log(f"RegisterAgent: {failure[0]}: {failure[1]}")
                return
            self.call("/org/bluez", AGENT_MANAGER, "RequestDefaultAgent",
                      GLib.Variant("(o)", (AGENT_PATH,)), done=defaulted)

        def defaulted(failure):
            # Not the default still answers for our own Pair calls.
            if failure:
                log(f"RequestDefaultAgent: {failure[0]}: {failure[1]}")
            emit("ready")

        self.call("/org/bluez", AGENT_MANAGER, "RegisterAgent",
                  GLib.Variant("(os)", (AGENT_PATH, "KeyboardDisplay")), done=registered)

    def on_bluez_down(self, _bus, _name):
        if self.owner is None:
            return  # it wasn't running when we started
        self.owner = None
        self.drop_asking()
        for device in list(self.showing):
            self.unshow(device)
        emit("down")

    def on_properties(self, _bus, sender, path, _interface, _signal, params):
        if sender != self.owner or path not in self.showing:
            return
        _, changed, _ = params.unpack()
        if changed.get("Paired") is True or changed.get("Connected") is False:
            self.unshow(path)

    # ── org.bluez.Agent1 ──────────────────────────────────────────────────

    def on_call(self, _bus, sender, _path, _interface, method, params, invocation):
        if sender != self.owner:
            invocation.return_dbus_error(REJECTED, "Only bluetoothd may ask")
            return
        args = params.unpack()

        if method in ("Release", "Cancel"):
            # Cancel: bluetoothd gave up on the question it's waiting for.
            self.drop_asking()
            invocation.return_value(None)
        elif method == "RequestPinCode":
            self.ask(invocation, "pin", args[0])
        elif method == "RequestPasskey":
            self.ask(invocation, "passkey", args[0])
        elif method == "RequestConfirmation":
            self.ask(invocation, "confirm", args[0], passkey=f"{args[1]:06d}")
        elif method == "RequestAuthorization":
            self.ask(invocation, "authorize", args[0])
        elif method == "AuthorizeService":
            device, uuid = args
            allow = self.graced(device)
            if allow is None:
                self.ask(invocation, "service", device, uuid=uuid)
            elif allow:
                invocation.return_value(None)
            else:
                invocation.return_dbus_error(REJECTED, "Refused")
        elif method == "DisplayPinCode":
            self.show(args[0], "show-pin", pincode=args[1])
            invocation.return_value(None)
        elif method == "DisplayPasskey":
            self.show(args[0], "show-passkey", passkey=f"{args[1]:06d}", entered=args[2])
            invocation.return_value(None)

    def ask(self, invocation, kind, device, **extra):
        rid = self.new_id()
        self.asking[rid] = (invocation, kind, device)
        emit("request", id=rid, kind=kind, device=device, **extra)

    def show(self, device, kind, **extra):
        rid = self.showing.get(device)
        if rid is None:
            rid = self.showing[device] = self.new_id()
            GLib.timeout_add_seconds(SHOW_TIMEOUT, self.show_expired, device, rid)
        emit("request", id=rid, kind=kind, device=device, **extra)

    def show_expired(self, device, rid):
        if self.showing.get(device) == rid:
            self.unshow(device)
        return GLib.SOURCE_REMOVE

    def unshow(self, device):
        rid = self.showing.pop(device, None)
        if rid is not None:
            emit("cancel", id=rid)

    def drop_asking(self):
        for rid, (invocation, _, _) in list(self.asking.items()):
            invocation.return_dbus_error(CANCELED, "Canceled")
            emit("cancel", id=rid)
        self.asking.clear()

    def new_id(self):
        rid = self.next_id
        self.next_id += 1
        return rid

    def set_grace(self, device, allow, seconds):
        self.grace[device] = (allow, time.monotonic() + seconds)

    def graced(self, device):
        allow, until = self.grace.get(device, (None, 0))
        return allow if time.monotonic() < until else None

    # ── commands ──────────────────────────────────────────────────────────

    def reply(self, rid, accept, value, always):
        shown = next((d for d, i in self.showing.items() if i == rid), None)
        if shown is not None:
            # Dismissing a code on screen stops the pairing it belongs to.
            self.unshow(shown)
            if not accept:
                self.cancel(shown)
            return

        entry = self.asking.pop(rid, None)
        if entry is None:
            return  # bluetoothd already gave up on it
        invocation, kind, device = entry

        if not accept:
            if kind == "service":
                self.set_grace(device, False, GRACE_DENY)
            else:
                self.quiet.add(device)
            invocation.return_dbus_error(REJECTED, "Refused by the user")
        elif kind == "pin":
            pin = str(value or "")
            if 1 <= len(pin) <= 16:
                invocation.return_value(GLib.Variant("(s)", (pin,)))
            else:
                invocation.return_dbus_error(REJECTED, "PIN must be 1-16 characters")
        elif kind == "passkey":
            key = str(value or "")
            if key.isdigit() and int(key) <= 999999:
                invocation.return_value(GLib.Variant("(u)", (int(key),)))
            else:
                invocation.return_dbus_error(REJECTED, "Passkey must be 0-999999")
        else:
            if kind == "service":
                self.set_grace(device, True, GRACE_ALLOW)
                if always:
                    self.trust(device)
            invocation.return_value(None)

    def pair(self, device):
        self.quiet.discard(device)
        self.set_grace(device, True, PAIR_TIMEOUT + GRACE_CONNECT)

        def paired(failure):
            self.unshow(device)
            if failure and failure[0] != "org.bluez.Error.AlreadyExists":
                self.grace.pop(device, None)
                error = "" if device in self.quiet else describe(*failure)
                self.quiet.discard(device)
                emit("result", op="pair", device=device, ok=False, error=error)
                return
            emit("result", op="pair", device=device, ok=True, error="")
            self.trust(device)
            self.connect(device, after_pair=True)

        self.call(device, DEVICE, "Pair", timeout=PAIR_TIMEOUT, done=paired)

    def connect(self, device, after_pair=False):
        self.set_grace(device, True, CONNECT_TIMEOUT + GRACE_CONNECT)

        def connected(failure):
            self.set_grace(device, True, GRACE_CONNECT)
            error = describe(*failure) if failure else ""
            if failure and failure[0] == "org.bluez.Error.AlreadyConnected":
                error = ""
            # A phone, say, pairs fine but offers nothing to connect to.
            if after_pair and error == NOTHING_TO_CONNECT:
                error = ""
            emit("result", op="connect", device=device, ok=not error, error=error)

        self.call(device, DEVICE, "Connect", timeout=CONNECT_TIMEOUT, done=connected)

    def cancel(self, device):
        self.quiet.add(device)
        self.call(device, DEVICE, "CancelPairing", done=lambda _failure: None)

    def trust(self, device):
        self.call(device, PROPERTIES, "Set",
                  GLib.Variant("(ssv)", (DEVICE, "Trusted", GLib.Variant("b", True))))

    # ── stdin ─────────────────────────────────────────────────────────────

    def on_stdin(self, fd, condition):
        data = os.read(fd, 65536) if condition & GLib.IOCondition.IN else b""
        if not data:
            self.quit()
            return GLib.SOURCE_REMOVE
        self.buffer += data
        while b"\n" in self.buffer:
            line, self.buffer = self.buffer.split(b"\n", 1)
            if line.strip():
                self.command(line)
        return GLib.SOURCE_CONTINUE

    def command(self, line):
        try:
            msg = json.loads(line)
            cmd = msg["cmd"]
            if cmd == "reply":
                self.reply(int(msg["id"]), bool(msg.get("accept")),
                           msg.get("value"), bool(msg.get("always")))
            elif cmd in ("pair", "connect", "cancel"):
                device = str(msg["device"])
                if not device.startswith("/org/bluez/"):
                    raise ValueError(f"not a BlueZ device: {device}")
                getattr(self, cmd)(device)
            else:
                raise ValueError(f"unknown command {cmd!r}")
        except (ValueError, KeyError, TypeError) as err:
            log(f"bad command {line!r}: {err}")


def main():
    loop = GLib.MainLoop()
    try:
        bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    except GLib.Error as err:
        log(f"no system bus: {err.message}")
        return 1
    Agent(bus, loop.quit)
    loop.run()
    return 0


if __name__ == "__main__":
    sys.exit(main())
