# sunshine-virtual-display

Juega en la tele desde tu PC con Linux usando [Sunshine](https://github.com/LizardByte/Sunshine) + [Moonlight](https://moonlight-stream.org/) a la **resolución nativa del cliente** (hasta 4K60, o 1440p/1080p a 120 Hz), sin enchufes HDMI falsos y **con tus monitores apagados** mientras juegas.

> **Desarrollado y probado en [CachyOS](https://cachyos.org/)** (basado en Arch) con KDE Plasma 6 en Wayland y una gráfica AMD. No se ha probado en otras distribuciones ni con otras gráficas.

*[Read in English](README.md)*

Al empezar una sesión de Moonlight:

1. Se enciende una pantalla virtual (un conector HDMI libre con un EDID falso) a la resolución y frecuencia que ha pedido el cliente de Moonlight.
2. Se apagan tus monitores y Sunshine captura solo la pantalla virtual.
3. Se desbloquea la sesión.

Al terminar vuelven los monitores que tenías encendidos, se apaga la pantalla virtual y la sesión se bloquea de nuevo.

## Modos disponibles

La pantalla virtual sigue lo que pide el cliente de Moonlight (`SUNSHINE_CLIENT_WIDTH/HEIGHT/FPS`), así que una tele 4K, un monitor 1440p y una Steam Deck reciben cada uno su resolución nativa. El EDID ofrece estos modos, todos dentro de HDMI 2.0:

| Resolución | Frecuencias |
|---|---|
| 3840×2160 | 60, 30 |
| 2560×1440 | 120, 60 |
| 1920×1200 | 60 |
| 1920×1080 | 120, 60 |
| 1280×800 (Steam Deck) | 60 |
| 1280×720 | 60 |

Si el cliente pide otra cosa (por ejemplo, un ultrapanorámico de 3440×1440), se usa `VIRTUAL_MODE` y Moonlight reescala la imagen. El 4K a 120 Hz no está incluido porque necesita HDMI 2.1.

## Probado en

Todo el proyecto se ha desarrollado y probado en este equipo:

- CachyOS (Arch), kernel 7.2 (linux-cachyos), KDE Plasma 6 en Wayland, Plasma Login Manager
- AMD Radeon RX 9070 XT (amdgpu, codificación Vulkan: H.264 / HEVC / AV1)
- systemd-boot gestionado con `sdboot-manage`, `mkinitcpio`
- Sunshine 2026.922, Moonlight TV 1.6 en una tele LG con webOS

Probablemente funcione en otras distribuciones basadas en Arch con KDE Wayland y amdgpu. Con otros drivers de gráfica (NVIDIA, Intel), otros gestores de arranque y otros escritorios no está probado, y fuera de KDE habría que sustituir `kscreen-doctor`. **Úsalo bajo tu responsabilidad:** cambia los parámetros del kernel y el initramfs.

## Requisitos

- KDE Plasma 6 (Wayland): `kscreen-doctor`, `loginctl`, `python3`
- Un conector **libre** en la gráfica para la pantalla virtual, por ejemplo `HDMI-A-1`, con un nombre que no se repita en otra gráfica. Una vez configurado, cualquier monitor que conectes a ese puerto se tratará como la pantalla virtual, así que déjalo libre.
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

Para el vigilante y el atajo de emergencia (más abajo), guarda el usuario y la contraseña del panel web de Sunshine, así los scripts pueden cerrar una sesión a través de su API:

```sh
umask 077
printf 'SUNSHINE_USER=%s\nSUNSHINE_PASSWORD=%s\n' 'tu-usuario' 'tu-contraseña' > ~/.config/sunshine-virtual-display/credentials
```

Para deshacer la parte del kernel: `sudo install/uninstall-edid.sh HDMI-A-1`. `install-edid.sh` también guarda una copia de `/etc/sdboot-manage.conf` en `/etc/sdboot-manage.conf.bak-sunshine`.

### Recuperar tus monitores

Sunshine solo ejecuta el comando `undo` (el que devuelve tus monitores) cuando la aplicación se **cierra**. Si la tele se congela, la apagas o sales sin cerrar, tus monitores se quedarían apagados. Hay tres cosas que lo evitan:

- **Vigilante** (`watchdog.py`, un servicio de usuario de systemd): si el cliente lleva `DISCONNECT_TIMEOUT` segundos desconectado (120 por defecto), cierra la sesión de Sunshine y vuelven tus monitores.
- **Atajo de emergencia `Meta+Shift+M`** (`restore-monitors.sh`): devuelve tus monitores al instante y cierra la sesión, sin bloquear. KDE carga el atajo en tu siguiente inicio de sesión.
- En Moonlight, activa **"Cerrar la aplicación al terminar"** (`quitappafter = true` en Moonlight TV), para que al salir se cierre la aplicación en el momento.

### Encender el PC desde el sofá

Sunshine solo funciona dentro de una sesión gráfica iniciada. Lo más sencillo y fiable es **suspender** el PC en vez de apagarlo y usar *Despertar* en Moonlight (Wake-on-LAN): tu sesión sigue abierta.

Para encenderlo desde apagado necesitas el inicio de sesión automático (*Configuración del sistema → Pantalla de inicio de sesión*) y `LOCK_ON_LOGIN=1`. El inconveniente es que el monedero de KDE no se abre al entrar, así que te pedirá su contraseña aparte. Activa Wake-on-LAN en la BIOS y en la tarjeta de red (`nmcli connection modify <conexión> 802-3-ethernet.wake-on-lan magic`).

## Seguridad

- Con `UNLOCK_ON_STREAM=1` (lo que viene por defecto), **cualquier cliente de Moonlight emparejado recibe tu escritorio desbloqueado**. Empareja solo tus dispositivos y borra los antiguos desde el panel web de Sunshine (*PIN* / *Clients*).
- Con el inicio de sesión automático, quien encienda el PC tiene tu sesión abierta unos segundos, hasta que `on-login.sh` la bloquea. Además, el monedero de KDE (KWallet) no se abre al entrar, así que las apps que lo usan te pedirán su contraseña.
- El fichero `credentials` guarda la contraseña del panel web de Sunshine sin cifrar (con permisos 600, solo la puedes leer tú).
- Pon `UNLOCK_ON_STREAM=0` si prefieres escribir la contraseña en la tele.

## Configuración

`~/.config/sunshine-virtual-display/config` (mira [examples/config](examples/config)):

| Variable | Por defecto | Qué hace |
|---|---|---|
| `VIRTUAL` | `HDMI-A-1` | Conector de la pantalla virtual (tiene que coincidir con los parámetros del kernel) |
| `MATCH_CLIENT` | `1` | Usar la resolución y los fps que pide el cliente de Moonlight |
| `VIRTUAL_MODE` | `3840x2160@60` | Modo de respaldo cuando la resolución del cliente no está en el EDID |
| `VIRTUAL_SCALE` | `auto` | `auto` (200 % en 4K, 150 % en 1440p, 100 % por debajo) o un valor fijo |
| `PRIMARY` / `PRIMARY_MODE` | vacío | Tu monitor principal y su resolución, que se restauran indicando resolución y posición |
| `UNLOCK_ON_STREAM` | `1` | Desbloquear la sesión al empezar a jugar |
| `LOCK_ON_STREAM_END` | `0` | Bloquearla al terminar |
| `LOCK_ON_LOGIN` | `0` | Bloquearla nada más iniciar sesión (para el inicio automático) |
| `DISCONNECT_TIMEOUT` | `120` | Segundos sin el cliente antes de que el vigilante cierre la sesión; `0` lo desactiva |

## Cómo funciona

| Pieza | Qué hace |
|---|---|
| `edid/gen_edid.py` | Genera un EDID HDMI (4K60 como modo preferido, más 1440p/1080p hasta 120 Hz y modos 16:10) que pasa `edid-decode --check`. Incluye el bloque HDMI Forum (600 MHz), sin el cual amdgpu no acepta 594 MHz por HDMI. |
| `drm.edid_firmware=… video=HDMI-A-1:e` | Parámetros del kernel que cargan el EDID y fuerzan el conector como conectado al arrancar. El EDID tiene que estar dentro del initramfs. |
| `scripts/stream-start.sh` | Comando `do` de Sunshine: apunta qué monitores estaban encendidos, enciende la virtual, apaga los monitores y desbloquea. Si la virtual no se puede encender, no toca los monitores y termina con error, así que Sunshine cancela la sesión. |
| `scripts/stream-stop.sh` | Comando `undo` de Sunshine: vuelve a encender los monitores guardados (o cualquiera conectado), apaga la virtual y, si está configurado, bloquea. |
| `scripts/on-login.sh` | Autoarranque: apaga la virtual, enciende todos los monitores conectados y, si está configurado, bloquea. |
| `scripts/watchdog.py` | Servicio de usuario: cierra la sesión de Sunshine cuando el cliente lleva un rato desconectado. |
| `scripts/restore-monitors.sh` | `Meta+Shift+M`: devuelve los monitores y cierra la sesión, sin bloquear. |

## Problemas que nos encontramos (y cómo los resuelven los scripts)

- **`global_prep_cmd` con `sh -c '…'` falla con código de salida 2.** Sunshine no gestiona bien las comillas anidadas, así que se llama a un script.
- **Monitor apagado → falla la captura** ("Failed to initialize video capture/encoding. Is a display connected and turned on?"). La captura KMS necesita una salida activa, y por eso existe la pantalla virtual.
- **KDE recuerda una configuración por cada combinación de monitores conectados.** Si una sesión termina mal, KDE puede guardar "monitor apagado, virtual encendida" para esa combinación, y al enchufar o desenchufar un segundo monitor se apaga el principal. `on-login.sh` y `restore_real` lo corrigen siempre.
- **Un monitor en reposo deja de anunciarse como conectado.** Si solo se restauran los monitores "conectados", ese se queda fuera, así que los scripts también prueban con los guardados y con el principal.
- **Sunshine ejecuta los comandos desde un servicio de usuario de systemd, fuera de la sesión.** Un `loginctl unlock-session` sin más solo funciona si `XDG_SESSION_ID` está exportada ahí por casualidad, así que los scripts buscan la sesión gráfica con `loginctl show-user <usuario> -p Display`.
- **En nuestras pruebas, KDE rechazaba en silencio encender un monitor que se solapaba con otra salida.** Primero se aparta la virtual y luego se enciende el monitor principal con su resolución y posición.
- **Forzar el conector desde debugfs no avisa a KWin.** `udevadm trigger --subsystem-match=drm --action=change` sí lo hace.
- **Bloquear la sesión mientras KDE todavía está cambiando de pantallas** dejaba la pantalla de bloqueo sin dibujar en el monitor (solo volvía cambiando de terminal, por ejemplo con Ctrl+Alt+F1). El bloqueo al terminar viene desactivado y, si lo activas, espera unos segundos.
- **Una sesión congelada o abandonada deja los monitores apagados**, porque Sunshine solo ejecuta `undo` al cerrar la aplicación. El vigilante y el atajo de emergencia lo resuelven.
- **Una combinación de monitores nueva al arrancar** (por ejemplo, un segundo monitor que casi nunca enciendes) hace que KDE active todas las salidas, virtual incluida, y el cuadro de contraseña puede acabar en una pantalla que no ves. `on-login.sh` lo resuelve.

## Consejos para Moonlight

- Panel de estadísticas en Moonlight TV (webOS): **mantén pulsado ATRÁS** mientras juegas.
- **No actives AV1 en Moonlight TV (webOS).** En nuestra LG OLED (2024) congelaba la imagen en el primer fotograma mientras el audio seguía sonando. Con HEVC funciona bien.
- 4K60 con HEVC: 40 Mbps va bien en nuestro equipo; sube a 50–80 Mbps si tu red lo permite (el puerto Ethernet de las teles LG es de 100 Mbps).
- Moonlight TV para LG webOS no está en la tienda de LG. Se instala con el Modo Desarrollador y el [Homebrew Channel](https://github.com/webosbrew/webos-homebrew-channel), o con `ares-install` / [webOS Dev Manager](https://github.com/webosbrew/dev-manager-desktop).

## Licencia

MIT
