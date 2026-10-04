# sunshine-virtual-display

Stream games from a Linux PC to a TV with [Sunshine](https://github.com/LizardByte/Sunshine) + [Moonlight](https://moonlight-stream.org/) at the **client's native resolution** (up to 4K60, or 1440p/1080p at 120 Hz), without a dummy HDMI plug and **with your real monitors turned off** while you play.

> **Developed and tested on [CachyOS](https://cachyos.org/)** (Arch-based) with KDE Plasma 6 on Wayland and an AMD GPU. Other distributions and GPUs have not been tested.

*[Leer en español](README.es.md)*

When a Moonlight session starts:

1. A virtual display (a free HDMI connector with a fake EDID) is turned on at the resolution and refresh rate the Moonlight client asked for.
2. Your real monitors are turned off, and Sunshine captures only the virtual display.
3. The session is unlocked.

When the session ends, the monitors that were on come back, the virtual display is turned off, and the session is locked again.

## Supported modes

The virtual display follows what the Moonlight client asks for (`SUNSHINE_CLIENT_WIDTH/HEIGHT/FPS`), so a 4K TV, a 1440p monitor and a Steam Deck each get their native resolution. The EDID offers these modes, all within HDMI 2.0:

| Resolution | Refresh rates |
|---|---|
| 3840×2160 | 60, 30 |
| 2560×1440 | 120, 60 |
| 1920×1200 | 60 |
| 1920×1080 | 120, 60 |
| 1280×800 (Steam Deck) | 60 |
| 1280×720 | 60 |

If the client asks for anything else (e.g. an ultrawide 3440×1440), `VIRTUAL_MODE` is used and Moonlight scales the picture. 4K at 120 Hz is not included because it needs HDMI 2.1.

## Tested on

The whole project was developed and tested on this machine:

- CachyOS (Arch), kernel 7.2 (linux-cachyos), KDE Plasma 6 on Wayland, Plasma Login Manager
- AMD Radeon RX 9070 XT (amdgpu, Vulkan encoding: H.264 / HEVC / AV1)
- systemd-boot managed by `sdboot-manage`, `mkinitcpio`
- Sunshine 2026.922, Moonlight TV 1.6 on an LG webOS TV

Other Arch-based distributions with KDE Wayland and amdgpu will probably work. Other GPU drivers (NVIDIA, Intel), bootloaders and desktops are untested, and desktops other than KDE need a replacement for `kscreen-doctor`. **Use it at your own risk:** it changes kernel parameters and the initramfs.

## Requirements

- KDE Plasma 6 (Wayland): `kscreen-doctor`, `loginctl`, `python3`
- A **free** GPU connector for the virtual display, e.g. `HDMI-A-1`, whose name is unique across your GPUs. Once it is configured, a real monitor plugged into that port is treated as the virtual display, so keep it free.
- Sunshine already working (`systemctl --user status app-dev.lizardbyte.app.Sunshine`)

## Install

```sh
git clone https://github.com/jjalcantara-dev/sunshine-virtual-display
cd sunshine-virtual-display

# 1. Find a free connector on the GPU that encodes (status "disconnected")
for c in /sys/class/drm/card*-*; do echo "$(basename $c) $(cat $c/status)"; done

# 2. Optional: try it without touching anything permanent (lost on reboot)
sudo install/test-virtual.sh HDMI-A-1
kscreen-doctor -o        # the new output should list 3840x2160@60

# 3. Make it permanent: EDID firmware, initramfs and kernel parameters
sudo install/install-edid.sh HDMI-A-1

# 4. Install the scripts for your user, then edit the config
install/install-user.sh
$EDITOR ~/.config/sunshine-virtual-display/config
```

Add the two lines printed by `install-user.sh` to `~/.config/sunshine/sunshine.conf` (see [examples/sunshine.conf](examples/sunshine.conf)), restart Sunshine and reboot.

For the watchdog and the emergency shortcut (see below), store your Sunshine web UI credentials so the scripts can end a session through Sunshine's API:

```sh
umask 077
printf 'SUNSHINE_USER=%s\nSUNSHINE_PASSWORD=%s\n' 'your-user' 'your-password' > ~/.config/sunshine-virtual-display/credentials
```

To undo the kernel part: `sudo install/uninstall-edid.sh HDMI-A-1`. `install-edid.sh` also keeps a backup of `/etc/sdboot-manage.conf` in `/etc/sdboot-manage.conf.bak-sunshine`.

### Getting your monitors back

Sunshine only runs the `undo` command (which brings your monitors back) when the app is **closed**. If the TV freezes, is turned off, or you leave without quitting, your monitors would stay off. Three things take care of that:

- **Watchdog** (`watchdog.py`, a systemd user service): if the client has been gone for `DISCONNECT_TIMEOUT` seconds (120 by default), it closes the Sunshine session and your monitors come back.
- **Emergency shortcut `Meta+Shift+M`** (`restore-monitors.sh`): brings your monitors back immediately and ends the session, without locking. KDE loads the shortcut at your next login.
- In Moonlight, enable **"Quit app after session"** (`quitappafter = true` in Moonlight TV) so leaving the stream closes the app right away.

### Waking the PC from the couch

Sunshine only runs inside a logged-in graphical session. The simplest reliable setup is to **suspend** the PC instead of shutting it down and use *Wake* in Moonlight (Wake-on-LAN): your session is still there.

To wake it from a full shutdown you need auto-login (*System Settings → Login Screen*) and `LOCK_ON_LOGIN=1`. Downside: KDE Wallet is not unlocked at login, so you will be asked for its password separately. Enable Wake-on-LAN in the BIOS and on the NIC (`nmcli connection modify <con> 802-3-ethernet.wake-on-lan magic`).

## Security

- With `UNLOCK_ON_STREAM=1` (the default), **any paired Moonlight client gets your unlocked desktop**. Pair only your own devices, and remove old ones from Sunshine's web UI (*PIN* / *Clients*).
- With auto-login, anyone who powers the PC on gets your session for a few seconds, until `on-login.sh` locks it. Your KDE Wallet is not unlocked at login either, so apps that use it will ask for its password.
- The `credentials` file holds your Sunshine web UI password in plain text (mode 600, readable only by you).
- Set `UNLOCK_ON_STREAM=0` if you prefer to type your password on the TV.

## Configuration

`~/.config/sunshine-virtual-display/config` (see [examples/config](examples/config)):

| Variable | Default | Meaning |
|---|---|---|
| `VIRTUAL` | `HDMI-A-1` | Connector of the virtual display (must match the kernel parameters) |
| `MATCH_CLIENT` | `1` | Use the resolution and fps requested by the Moonlight client |
| `VIRTUAL_MODE` | `3840x2160@60` | Fallback mode when the client's resolution is not in the EDID |
| `VIRTUAL_SCALE` | `auto` | `auto` (200% at 4K, 150% at 1440p, 100% below) or a fixed value |
| `PRIMARY` / `PRIMARY_MODE` | empty | Your main monitor and its mode, restored with an explicit mode and position |
| `UNLOCK_ON_STREAM` | `1` | Unlock the session when a stream starts |
| `LOCK_ON_STREAM_END` | `0` | Lock it when the stream ends |
| `LOCK_ON_LOGIN` | `0` | Lock it right after login (for auto-login setups) |
| `DISCONNECT_TIMEOUT` | `120` | Seconds without the client before the watchdog ends the session; `0` disables it |

## How it works

| Piece | What it does |
|---|---|
| `edid/gen_edid.py` | Generates an HDMI EDID (4K60 preferred, plus 1440p/1080p up to 120 Hz and 16:10 modes) that passes `edid-decode --check`. It includes the HDMI Forum VSDB (600 MHz), which amdgpu needs to accept 594 MHz over HDMI. |
| `drm.edid_firmware=… video=HDMI-A-1:e` | Kernel parameters that load the EDID and force the connector on at boot. The initramfs must contain the EDID. |
| `scripts/stream-start.sh` | Sunshine `do` command: saves which monitors are on, enables the virtual display, disables the monitors, unlocks. If the virtual display cannot be enabled, it leaves the monitors alone and exits with an error, so Sunshine aborts the stream. |
| `scripts/stream-stop.sh` | Sunshine `undo` command: restores the saved monitors (or any connected one), disables the virtual display, optionally locks. |
| `scripts/on-login.sh` | Autostart: turns the virtual display off and every connected monitor on, optionally locks. |
| `scripts/watchdog.py` | User service: ends the Sunshine session when the client has been gone for a while. |
| `scripts/restore-monitors.sh` | `Meta+Shift+M`: brings the monitors back and ends the session, without locking. |

## Pitfalls we hit (and how the scripts handle them)

- **`global_prep_cmd` with `sh -c '…'` fails with exit code 2.** Sunshine does not handle nested quotes well, so call a script instead.
- **Monitor off → capture fails** ("Failed to initialize video capture/encoding. Is a display connected and turned on?"). KMS capture needs an active output, and that is why the virtual display exists.
- **KDE remembers one layout per set of connected monitors.** If a stream ends badly, KDE can save "real monitor off, virtual on" for that set, and plugging or unplugging a second monitor then turns your main one off. `on-login.sh` and `restore_real` always fix this.
- **A monitor in standby stops reporting itself as connected.** Restoring only "connected" monitors misses it, so the scripts also try the saved and preferred monitors.
- **Sunshine runs the prep commands from a systemd user service, outside the session.** A bare `loginctl unlock-session` only works if `XDG_SESSION_ID` happens to be exported there, so the scripts look up the graphical session with `loginctl show-user <user> -p Display`.
- **In our tests, KDE silently rejected enabling a monitor that overlaps another output.** The virtual display is moved away first, and the main monitor is enabled with an explicit mode and position.
- **Forcing the connector from debugfs does not notify KWin.** `udevadm trigger --subsystem-match=drm --action=change` does.
- **Locking the session while KDE is still switching outputs** left the lock screen undrawn on the monitor (only switching VTs, e.g. Ctrl+Alt+F1, brought it back). Locking at stream end is now off by default, and waits a few seconds when enabled.
- **A frozen or abandoned stream keeps the monitors off**, because Sunshine only runs `undo` when the app is closed. The watchdog and the emergency shortcut handle this.
- **A new monitor combination at boot** (e.g. a second monitor you rarely use) makes KDE enable every output, including the virtual one, so the login prompt can end up on a screen you cannot see. `on-login.sh` handles this.

## Moonlight tips

- Status overlay in Moonlight TV (webOS): **long-press BACK** while streaming.
- **Do not enable AV1 in Moonlight TV (webOS).** On our LG OLED (2024) it froze the picture on the first frame while audio kept playing. HEVC works fine.
- 4K60 with HEVC: 40 Mbps works well on our setup; go up to 50–80 Mbps if your network allows it (LG TV Ethernet ports are 100 Mbps).
- Moonlight TV for LG webOS is not in the LG store. Install it with Developer Mode and the [Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel), or `ares-install` / [webOS Dev Manager](https://github.com/webosbrew/dev-manager-desktop).

## License

MIT
