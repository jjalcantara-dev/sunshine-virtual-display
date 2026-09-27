# sunshine-virtual-display

Juega en la tele desde tu PC con Linux usando [Sunshine](https://github.com/LizardByte/Sunshine) + [Moonlight](https://moonlight-stream.org/) en **4K60 nativo**, sin enchufes HDMI falsos y **con tus monitores apagados** mientras juegas.

*[Read in English](README.md)*

Al empezar una sesión de Moonlight:

1. Se enciende una pantalla virtual de 3840×2160 a 60 Hz: un conector HDMI libre con un EDID falso.
2. Se apagan tus monitores y Sunshine captura solo la pantalla virtual.
3. Se desbloquea la sesión.

Al terminar vuelven los monitores que tenías encendidos, se apaga la pantalla virtual y la sesión se bloquea de nuevo.

## Probado en

- CachyOS (Arch), KDE Plasma 6 en Wayland, Plasma Login Manager
- AMD Radeon RX 9070 XT (amdgpu, codificación Vulkan: H.264 / HEVC / AV1)
- systemd-boot gestionado con `sdboot-manage`, `mkinitcpio`
- Sunshine 2026.922, Moonlight TV 1.6 en una tele LG con webOS

Debería funcionar en otros equipos con KDE Wayland y amdgpu. En otros escritorios habría que sustituir `kscreen-doctor`. **Úsalo bajo tu responsabilidad:** cambia los parámetros del kernel y el initramfs.

## Requisitos

- KDE Plasma 6 (Wayland): `kscreen-doctor`, `loginctl`, `python3`
- Un conector **libre** en la gráfica para la pantalla virtual, por ejemplo `HDMI-A-1`. Una vez configurado, cualquier monitor que conectes a ese puerto se tratará como la pantalla virtual, así que déjalo libre.
- Sunshine funcionando ya (`systemctl --user status app-dev.lizardbyte.app.Sunshine`)

## Instalación

```sh
git clone https://github.com/jjalcantara-dev/sunshine-virtual-display
cd sunshine-virtual-display

# 1. Busca un conector libre en la gráfica que codifica (estado "disconnected")
for c in /sys/class/drm/card*-*; do echo "$(basename $c) $(cat $c/status)"; done

# 2. Opcional: pruébalo sin tocar nada permanente (se pierde al reiniciar)
sudo install/test-virtual.sh HDMI-A-1
kscreen-doctor -o        # debe aparecer una salida nueva con 3840x2160@60

# 3. Hazlo permanente: EDID, initramfs y parámetros del kernel
sudo install/install-edid.sh HDMI-A-1

# 4. Instala los scripts para tu usuario y ajusta la configuración
install/install-user.sh
$EDITOR ~/.config/sunshine-virtual-display/config
```

Añade las dos líneas que te muestra `install-user.sh` a `~/.config/sunshine/sunshine.conf` (mira [examples/sunshine.conf](examples/sunshine.conf)), reinicia Sunshine y reinicia el PC.

Para deshacer la parte del kernel: `sudo install/uninstall-edid.sh HDMI-A-1`. `install-edid.sh` también guarda una copia de `/etc/sdboot-manage.conf` en `/etc/sdboot-manage.conf.bak-sunshine`.

### Inicio automático (para encender el PC desde el sofá)

Sunshine solo funciona dentro de una sesión gráfica iniciada. Para encender el PC desde Moonlight (Wake-on-LAN) y jugar sin ir hasta él:

- Activa el inicio de sesión automático en *Configuración del sistema → Pantalla de inicio de sesión*.
- Deja `LOCK_ON_LOGIN=1`. La entrada de autoarranque bloquea la sesión nada más entrar. Quien esté delante del PC ve la pantalla de bloqueo, y Sunshine la desbloquea al empezar a jugar.
- Activa Wake-on-LAN en la BIOS y en la tarjeta de red (`nmcli connection modify <conexión> 802-3-ethernet.wake-on-lan magic`).

## Cómo funciona

| Pieza | Qué hace |
|---|---|
| `edid/gen_edid.py` | Genera un EDID HDMI 4K60 que pasa `edid-decode --check`. Incluye el bloque HDMI Forum (600 MHz), sin el cual amdgpu no acepta 594 MHz por HDMI. |
| `drm.edid_firmware=… video=HDMI-A-1:e` | Parámetros del kernel que cargan el EDID y fuerzan el conector como conectado al arrancar. El EDID tiene que estar dentro del initramfs. |
| `scripts/stream-start.sh` | Comando `do` de Sunshine: apunta qué monitores estaban encendidos, enciende la virtual, apaga los monitores y desbloquea. |
| `scripts/stream-stop.sh` | Comando `undo` de Sunshine: vuelve a encender los monitores guardados (o cualquiera conectado), apaga la virtual y bloquea. |
| `scripts/on-login.sh` | Autoarranque: apaga la virtual, enciende todos los monitores conectados y bloquea. |

## Problemas que nos encontramos (y cómo los resuelven los scripts)

- **`global_prep_cmd` con `sh -c '…'` falla con código de salida 2.** Sunshine no gestiona bien las comillas anidadas, así que se llama a un script.
- **Monitor apagado → falla la captura** ("Failed to initialize video capture/encoding. Is a display connected and turned on?"). La captura KMS necesita una salida activa, y por eso existe la pantalla virtual.
- **KDE recuerda una configuración por cada combinación de monitores conectados.** Si una sesión termina mal, KDE puede guardar "monitor apagado, virtual encendida" para esa combinación, y al enchufar o desenchufar un segundo monitor se apaga el principal. `on-login.sh` y `restore_real` lo corrigen siempre.
- **Un monitor en reposo deja de anunciarse como conectado.** Si solo se restauran los monitores "conectados", ese se queda fuera, así que los scripts también prueban con los guardados y con el principal.
- **KDE rechaza en silencio encender un monitor que se solapa con otra salida.** Primero se aparta la virtual y luego se enciende el monitor principal con su resolución y posición.
- **Forzar el conector desde debugfs no avisa a KWin.** `udevadm trigger --subsystem-match=drm --action=change` sí lo hace.
- **Una combinación de monitores nueva al arrancar** (por ejemplo, un segundo monitor que casi nunca enciendes) hace que KDE active todas las salidas, virtual incluida, y el cuadro de contraseña puede acabar en una pantalla que no ves. `on-login.sh` lo resuelve.

## Consejos para Moonlight

- Panel de estadísticas en Moonlight TV (webOS): **mantén pulsado ATRÁS** mientras juegas.
- Para 4K60, los 35 Mbps que trae por defecto se quedan cortos: prueba 50–80 Mbps (el puerto Ethernet de las teles LG es de 100 Mbps) y activa AV1 si tu tele lo decodifica.
- Moonlight TV para LG webOS no está en la tienda de LG. Se instala con el Modo Desarrollador y el [Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel), o con `ares-install` / [webOS Dev Manager](https://github.com/webosbrew/dev-manager-desktop).

## Licencia

MIT
