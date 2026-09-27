# sunshine-virtual-display

Stream games from a Linux PC to a TV with [Sunshine](https://github.com/LizardByte/Sunshine) + [Moonlight](https://moonlight-stream.org/) at **native 4K60**, without a dummy HDMI plug and **with your real monitors turned off** while you play.

> **Developed and tested on [CachyOS](https://cachyos.org/)** (Arch-based) with KDE Plasma 6 on Wayland and an AMD GPU. Other distributions and GPUs have not been tested.

*[Leer en español](README.es.md)*

When a Moonlight session starts:

1. A virtual 3840×2160@60 display (a free HDMI connector with a fake EDID) is turned on.
2. Your real monitors are turned off, and Sunshine captures only the virtual display.
3. The session is unlocked.

When the session ends, the monitors that were on come back, the virtual display is turned off, and the session is locked again.

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

To undo the kernel part: `sudo install/uninstall-edid.sh HDMI-A-1`. `install-edid.sh` also keeps a backup of `/etc/sdboot-manage.conf` in `/etc/sdboot-manage.conf.bak-sunshine`.

### Auto-login (to wake the PC from the couch)

Sunshine only runs inside a logged-in graphical session. To wake the PC from Moonlight (Wake-on-LAN) and play without walking to it:

- Enable auto-login: *System Settings → Login Screen*.
- Keep `LOCK_ON_LOGIN=1`. The autostart entry locks the session right after login. The lock screen stays up for anyone at the desk, and Sunshine unlocks it when you stream.
- Enable Wake-on-LAN in the BIOS and on the NIC (`nmcli connection modify <con> 802-3-ethernet.wake-on-lan magic`).

## Security

- With `UNLOCK_ON_STREAM=1` (the default), **any paired Moonlight client gets your unlocked desktop**. Pair only your own devices, and remove old ones from Sunshine's web UI (*PIN* / *Clients*).
- With auto-login, anyone who powers the PC on gets your session for a few seconds, until `on-login.sh` locks it. Your KDE Wallet is not unlocked at login either, so apps that use it will ask for its password.
- Set `UNLOCK_ON_STREAM=0` if you prefer to type your password on the TV.

## Configuration

`~/.config/sunshine-virtual-display/config` (see [examples/config](examples/config)):

| Variable | Default | Meaning |
|---|---|---|
| `VIRTUAL` | `HDMI-A-1` | Connector of the virtual display (must match the kernel parameters) |
| `VIRTUAL_MODE` / `VIRTUAL_SCALE` | `3840x2160@60` / `2` | Mode and scale of the virtual display |
| `PRIMARY` / `PRIMARY_MODE` | empty | Your main monitor and its mode, restored with an explicit mode and position |
| `UNLOCK_ON_STREAM` | `1` | Unlock the session when a stream starts |
| `LOCK_ON_STREAM_END` | `1` | Lock it when the stream ends |
| `LOCK_ON_LOGIN` | `1` | Lock it right after login |

## How it works

| Piece | What it does |
|---|---|
| `edid/gen_edid.py` | Generates a 4K60 HDMI EDID that passes `edid-decode --check`. It includes the HDMI Forum VSDB (600 MHz), which amdgpu needs to accept 594 MHz over HDMI. |
| `drm.edid_firmware=… video=HDMI-A-1:e` | Kernel parameters that load the EDID and force the connector on at boot. The initramfs must contain the EDID. |
| `scripts/stream-start.sh` | Sunshine `do` command: saves which monitors are on, enables the virtual display, disables the monitors, unlocks. If the virtual display cannot be enabled, it leaves the monitors alone and exits with an error, so Sunshine aborts the stream. |
| `scripts/stream-stop.sh` | Sunshine `undo` command: restores the saved monitors (or any connected one), disables the virtual display, locks. |
| `scripts/on-login.sh` | Autostart: turns the virtual display off and every connected monitor on, then locks. |

## Pitfalls we hit (and how the scripts handle them)

- **`global_prep_cmd` with `sh -c '…'` fails with exit code 2.** Sunshine does not handle nested quotes well, so call a script instead.
- **Monitor off → capture fails** ("Failed to initialize video capture/encoding. Is a display connected and turned on?"). KMS capture needs an active output, and that is why the virtual display exists.
- **KDE remembers one layout per set of connected monitors.** If a stream ends badly, KDE can save "real monitor off, virtual on" for that set, and plugging or unplugging a second monitor then turns your main one off. `on-login.sh` and `restore_real` always fix this.
- **A monitor in standby stops reporting itself as connected.** Restoring only "connected" monitors misses it, so the scripts also try the saved and preferred monitors.
- **Sunshine runs the prep commands from a systemd user service, outside the session.** A bare `loginctl unlock-session` only works if `XDG_SESSION_ID` happens to be exported there, so the scripts look up the graphical session with `loginctl show-user <user> -p Display`.
- **In our tests, KDE silently rejected enabling a monitor that overlaps another output.** The virtual display is moved away first, and the main monitor is enabled with an explicit mode and position.
- **Forcing the connector from debugfs does not notify KWin.** `udevadm trigger --subsystem-match=drm --action=change` does.
- **A new monitor combination at boot** (e.g. a second monitor you rarely use) makes KDE enable every output, including the virtual one, so the login prompt can end up on a screen you cannot see. `on-login.sh` handles this.

## Moonlight tips

- Status overlay in Moonlight TV (webOS): **long-press BACK** while streaming.
- 4K60 needs more than the default 35 Mbps: try 50–80 Mbps (LG TV Ethernet ports are 100 Mbps), and enable AV1 if your TV decodes it.
- Moonlight TV for LG webOS is not in the LG store. Install it with Developer Mode and the [Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel), or `ares-install` / [webOS Dev Manager](https://github.com/webosbrew/dev-manager-desktop).

## License

MIT
