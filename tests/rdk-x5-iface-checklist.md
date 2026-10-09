# RDK X5 board interface checklist

On-target bring-up checks for a flashed base `saha-image-robot` image (not the
accelerator variant). Run the automated phase-A helper on the board, then use
the B-section commands when the matching accessory is available.

Login (USB gadget):

```bash
ssh root@192.168.128.10
```

Empty root password. Host side needs `192.168.128.1/24` on the USB Ethernet
interface.

Automated phase A (on the board as root):

```bash
# from the repository on a development host, copy then run:
scp tests/check-rdk-x5-iface.sh root@192.168.128.10:/tmp/
ssh root@192.168.128.10 'bash /tmp/check-rdk-x5-iface.sh'
```

Or from a board checkout of this repository:

```bash
bash tests/check-rdk-x5-iface.sh
bash tests/check-rdk-x5-iface.sh --phase-b   # only items that can auto-detect accessories
```

Verdicts: `PASS`, `FAIL`, `ENUM_OK` (node present; cable/peer still needed),
`SKIP` (missing tool, accessory, or out of base-image scope).

## Scope

- Check: driver/node presence, link up, basic scan or I/O.
- Do not: destructive stress, PoE power validation, NAND bootloader changes.
- Skip on base image: BPU smoke and full MIPI camera capture
  (`SAHA_X5_ACCELERATORS=1` required).

## A. No accessory required (software enumeration)

| ID | Interface | Commands |
| --- | --- | --- |
| A1 | System / kernel | `uname -a; cat /etc/os-release; dmesg \| tail -50` |
| A2 | TF / rootfs | `lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINTS; findmnt /; df -h` |
| A3 | USB gadget | `ip -br link; ip -4 addr show usb0 usb1; networkctl status usb0 usb1` |
| A4 | eth0 | `ip -br link show eth0; ethtool eth0; networkctl status eth0` |
| A5 | Wi-Fi module | `nmcli device; nmcli radio; iw dev` |
| A6 | Bluetooth | `hciconfig -a; bluetoothctl show; ls /sys/class/bluetooth` |
| A7 | USB3 host | `lsusb; lsusb -t; dmesg \| grep -iE 'xhci\|hub' \| tail -30` |
| A8 | HDMI / DRM | `ls /dev/dri; cat /sys/class/drm/*/status; dmesg \| grep -iE 'drm\|hdmi' \| tail -20` |
| A9 | Audio | `aplay -l; arecord -l; cat /proc/asound/cards` |
| A10 | CAN | `ip link show type can; lsmod \| grep -iE 'can\|tcan'; dmesg \| grep -i can \| tail -20` |
| A11 | I2C | `ls /dev/i2c-*; i2cdetect -l` |
| A12 | SPI | `ls /dev/spidev* /sys/class/spi_master` |
| A13 | UART | `ls -l /dev/ttyS*; dmesg \| grep ttyS \| tail -20` |
| A14 | GPIO / PWM | `ls /dev/gpiochip* /sys/class/pwm; cat /sys/kernel/debug/gpio \| head -80` |
| A15 | MIPI CSI/DSI nodes | `ls /dev/video* /dev/media*; v4l2-ctl --list-devices; dmesg \| grep -iE 'mipi\|csi\|dsi\|v4l' \| tail -30` |
| A16 | RTC | `ls /dev/rtc*; timedatectl; hwclock -r` |
| A17 | SSH bring-up | `hostname; systemctl is-active sshd \|\| systemctl is-active ssh; ss -lntp \| grep :22` |

## B. Needs a simple accessory

| ID | Interface | Needs | Commands |
| --- | --- | --- | --- |
| B1 | eth0 reachability | Ethernet cable | `ping -c 3 8.8.8.8; ip -4 addr show eth0` |
| B2 | USB host | USB stick | before/after `lsusb; dmesg \| tail -20; lsblk`; optional 8 MiB write smoke |
| B3 | Wi-Fi associate | SSID / password | `nmcli dev wifi list; nmcli dev wifi connect SSID password PASS; ping` |
| B4 | Bluetooth scan | nearby device optional | `bluetoothctl power on; bluetoothctl scan on` |
| B5 | HDMI | display | `cat /sys/class/drm/*/status; modetest -c` |
| B6 | 3.5 mm audio | headset / speaker | `speaker-test -c 2 -t wav -l 1` or `aplay` PCM smoke |
| B7 | CAN | bus / peer | `ip link set can0 up type can bitrate 500000`; then `cansend` / `candump` |
| B8 | Debug UART | Micro-USB DEBUG | host: `tio -b 115200 /dev/ttyUSB0`, power-cycle board |
| B9 | 40-pin I2C device | known device | `i2cdetect -y BUS` |

Wi-Fi credentials for the helper (never commit secrets):

```bash
SAHA_WIFI_SSID='...' SAHA_WIFI_PASSWORD='...' bash tests/check-rdk-x5-iface.sh --b3
```

## C. Out of scope on base image

| ID | Interface | Reason |
| --- | --- | --- |
| C1 | BPU | Needs accelerator image + `saha-rdk-x5-bpu-smoke` |
| C2 | MIPI camera capture | Needs accelerator + supported sensor |
| C3 | MIPI DSI panel | Needs LCD; A15 only checks nodes |
| C4 | PoE | Needs PoE switch |

## Related docs

- Hardware and flash: [docs/hardware/rdk-x5.md](../docs/hardware/rdk-x5.md)
- Flash helper contract test: `bash tests/test-flash-rdk-x5.sh`
- Checklist contract test: `bash tests/test-rdk-x5-iface-checklist.sh`
