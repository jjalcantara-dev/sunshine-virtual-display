#!/usr/bin/env python3
"""End the Sunshine session when the Moonlight client has been gone for a while.

Sunshine only runs the prep "undo" command (which brings the monitors back) when the app is closed.
If the TV freezes, is turned off, or the user leaves without quitting, the session stays open and the
real monitors stay off. This follows Sunshine's log and, after DISCONNECT_TIMEOUT seconds without the
client reconnecting, closes the app through Sunshine's API so the undo command runs.
"""
import os
import shlex
import subprocess
import threading

UNIT = os.environ.get("SUNSHINE_UNIT", "app-dev.lizardbyte.app.Sunshine.service")
HERE = os.path.dirname(os.path.realpath(__file__))


def setting(name, default):
    """Read a variable from the user config the same way the shell scripts do."""
    cfg = os.path.join(os.environ.get("XDG_CONFIG_HOME", os.path.expanduser("~/.config")),
                       "sunshine-virtual-display", "config")
    try:
        out = subprocess.run(["sh", "-c", f'. {shlex.quote(cfg)} >/dev/null 2>&1; printf %s "${{{name}}}"'],
                             capture_output=True, text=True).stdout
        return out or default
    except OSError:
        return default


TIMEOUT = int(setting("DISCONNECT_TIMEOUT", "120"))
timer = None


def close_app():
    print(f"client gone for {TIMEOUT}s, closing the Sunshine session", flush=True)
    subprocess.run(["sh", "-c", f'. "{HERE}/common.sh"; sunshine_close_app'])


def main():
    global timer
    if TIMEOUT <= 0:
        print("DISCONNECT_TIMEOUT <= 0, watchdog disabled", flush=True)
        return
    log = subprocess.Popen(["journalctl", "--user", "-u", UNIT, "-f", "-n", "0", "-o", "cat"],
                           stdout=subprocess.PIPE, text=True)
    for line in log.stdout:
        if "CLIENT DISCONNECTED" in line:
            if timer:
                timer.cancel()
            timer = threading.Timer(TIMEOUT, close_app)
            timer.daemon = True
            timer.start()
        elif "CLIENT CONNECTED" in line and timer:
            timer.cancel()
            timer = None


if __name__ == "__main__":
    main()
