#!/usr/bin/env bash
# On-target RDK X5 interface bring-up checks for base saha-image-robot.
# Intended to run as root on the board. See tests/rdk-x5-iface-checklist.md.
set -euo pipefail

PASS_COUNT=0
FAIL_COUNT=0
ENUM_COUNT=0
SKIP_COUNT=0
RUN_PHASE_A=1
RUN_PHASE_B=0
REQUESTED_B=()

usage() {
  cat <<'USAGE'
Usage: tests/check-rdk-x5-iface.sh [options]

Run on the RDK X5 board as root after flashing base saha-image-robot.

Options:
  --phase-a          Run software enumeration A1-A17 (default)
  --phase-b          Also run B items that can auto-detect accessories
  --b1 .. --b9       Run a specific B item (implies not skipping that item)
  --all-b            Alias for --phase-b plus every B id
  -h, --help         Show this help

Environment for B3 (never commit secrets):
  SAHA_WIFI_SSID
  SAHA_WIFI_PASSWORD
USAGE
}

have_cmd() {
  command -v "$1" >/dev/null 2>&1
}

record() {
  local verdict=$1
  local id=$2
  local detail=$3
  printf '%-8s %-4s %s\n' "$verdict" "$id" "$detail"
  case "$verdict" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
    ENUM_OK) ENUM_COUNT=$((ENUM_COUNT + 1)) ;;
    SKIP) SKIP_COUNT=$((SKIP_COUNT + 1)) ;;
  esac
}

path_exists_any() {
  local pattern
  for pattern in "$@"; do
    # shellcheck disable=SC2086
    compgen -G "$pattern" >/dev/null && return 0
  done
  return 1
}

want_b() {
  local id=$1
  local item
  [ "$RUN_PHASE_B" -eq 1 ] && return 0
  for item in "${REQUESTED_B[@]:-}"; do
    [ "$item" = "$id" ] && return 0
  done
  return 1
}

check_a1() {
  if uname -a >/dev/null 2>&1 && [ -r /etc/os-release ]; then
    record PASS A1 "kernel=$(uname -r) distro=$(. /etc/os-release; printf '%s' "${ID:-unknown}")"
  else
    record FAIL A1 "uname or /etc/os-release unavailable"
  fi
}

check_a2() {
  if findmnt -n -o SOURCE / >/dev/null 2>&1; then
    local source
    source="$(findmnt -n -o SOURCE /)"
    case "$source" in
      *mmcblk*|*mmc*)
        record PASS A2 "root=$source"
        return
        ;;
    esac
    record ENUM_OK A2 "root=$source (expected mmcblk TF root)"
    return
  fi
  if grep -E ' / .*ext4' /proc/mounts | grep -q mmcblk; then
    record PASS A2 "root on mmcblk via /proc/mounts"
    return
  fi
  if df -h / >/dev/null 2>&1; then
    record ENUM_OK A2 "root mounted; findmnt missing, inspect df manually"
    return
  fi
  record FAIL A2 "cannot determine root device"
}

check_a3() {
  local ok=0
  if ip -br link show usb0 >/dev/null 2>&1; then ok=1; fi
  if ip -br link show usb1 >/dev/null 2>&1; then ok=1; fi
  if [ "$ok" -eq 1 ] && ip -4 addr show | grep -q '192\.168\.128\.10'; then
    record PASS A3 "usb gadget present with 192.168.128.10"
  elif [ "$ok" -eq 1 ]; then
    record ENUM_OK A3 "usb0/usb1 present without 192.168.128.10"
  else
    record FAIL A3 "usb0/usb1 missing"
  fi
}

check_a4() {
  if ! ip -br link show eth0 >/dev/null 2>&1; then
    record FAIL A4 "eth0 missing"
    return
  fi
  local carrier
  carrier="$(cat /sys/class/net/eth0/carrier 2>/dev/null || printf '0')"
  if [ "$carrier" = "1" ]; then
    record PASS A4 "eth0 carrier present"
  else
    record ENUM_OK A4 "eth0 present, no carrier (cable needed for B1)"
  fi
}

check_a5() {
  if ip -br link show wlan0 >/dev/null 2>&1 || iw dev >/dev/null 2>&1; then
    record PASS A5 "wlan interface present"
  else
    record FAIL A5 "wlan0 / iw missing"
  fi
}

check_a6() {
  if path_exists_any '/sys/class/bluetooth/hci*'; then
    record PASS A6 "bluetooth controller present"
  elif have_cmd bluetoothctl && bluetoothctl show >/dev/null 2>&1; then
    record PASS A6 "bluetoothctl show ok"
  else
    record FAIL A6 "no bluetooth controller"
  fi
}

check_a7() {
  if ! have_cmd lsusb; then
    record SKIP A7 "lsusb not installed"
    return
  fi
  if lsusb >/dev/null 2>&1 && dmesg | grep -qiE 'xhci|usb.*hub'; then
    record PASS A7 "xhci/hub enumerated"
  else
    record FAIL A7 "USB host enumeration failed"
  fi
}

check_a8() {
  if path_exists_any '/dev/dri/card*'; then
    if grep -Rqs connected /sys/class/drm/*/status 2>/dev/null; then
      record PASS A8 "DRM present with connected connector"
    else
      record ENUM_OK A8 "DRM present; HDMI disconnected or unknown"
    fi
  else
    record FAIL A8 "/dev/dri missing"
  fi
}

check_a9() {
  if [ -r /proc/asound/cards ] && grep -q '\[.*\]' /proc/asound/cards; then
    record PASS A9 "ALSA card present"
  elif have_cmd aplay && aplay -l 2>/dev/null | grep -q card; then
    record PASS A9 "aplay lists a card"
  else
    record FAIL A9 "no ALSA playback card"
  fi
}

check_a10() {
  if ip link show type can 2>/dev/null | grep -q can; then
    record PASS A10 "CAN netdev present"
  elif lsmod 2>/dev/null | grep -qiE 'tcan|m_can|can_dev'; then
    record ENUM_OK A10 "CAN modules loaded without netdev"
  else
    record FAIL A10 "CAN interface/modules missing"
  fi
}

check_a11() {
  if path_exists_any '/dev/i2c-*'; then
    record PASS A11 "I2C adapters present"
  else
    record FAIL A11 "/dev/i2c-* missing"
  fi
}

check_a12() {
  if path_exists_any '/dev/spidev*' '/sys/class/spi_master/spi*'; then
    record PASS A12 "SPI master/spidev present"
  else
    record FAIL A12 "SPI nodes missing"
  fi
}

check_a13() {
  if [ -e /dev/ttyS0 ]; then
    record PASS A13 "ttyS0 present"
  else
    record FAIL A13 "/dev/ttyS0 missing"
  fi
}

check_a14() {
  if path_exists_any '/dev/gpiochip*' && path_exists_any '/sys/class/pwm/pwmchip*'; then
    record PASS A14 "gpiochip and pwmchip present"
  elif path_exists_any '/dev/gpiochip*'; then
    record ENUM_OK A14 "gpiochip present; pwmchip missing"
  else
    record FAIL A14 "gpiochip missing"
  fi
}

check_a15() {
  local has_drm_dsi=0
  if dmesg 2>/dev/null | grep -qiE 'dsi-encoder|mipi'; then
    has_drm_dsi=1
  fi
  if path_exists_any '/dev/video*' '/dev/media*'; then
    record PASS A15 "V4L/media nodes present"
  elif [ "$has_drm_dsi" -eq 1 ]; then
    record ENUM_OK A15 "MIPI/DSI mentioned in dmesg; no /dev/video* on base image"
  else
    record ENUM_OK A15 "no V4L nodes (expected on base without camera stack)"
  fi
}

check_a16() {
  if path_exists_any '/dev/rtc' '/dev/rtc0'; then
    record PASS A16 "RTC device present"
  else
    record FAIL A16 "/dev/rtc* missing"
  fi
}

check_a17() {
  if [ "$(hostname 2>/dev/null || true)" = "sahaWorld" ] || hostname >/dev/null 2>&1; then
    :
  else
    record FAIL A17 "hostname unavailable"
    return
  fi
  if pgrep -x sshd >/dev/null 2>&1 || pgrep -f 'sshd-session|sshd@' >/dev/null 2>&1; then
    record PASS A17 "hostname=$(hostname) sshd running"
    return
  fi
  if systemctl is-active --quiet sshd 2>/dev/null || systemctl is-active --quiet ssh 2>/dev/null; then
    record PASS A17 "hostname=$(hostname) ssh service active"
    return
  fi
  # Socket-activated OpenSSH may show only genkeys until a session exists.
  if systemctl list-unit-files 2>/dev/null | grep -q '^sshd'; then
    record ENUM_OK A17 "sshd unit present (possibly socket-activated)"
    return
  fi
  record FAIL A17 "OpenSSH not detected"
}

run_phase_a() {
  printf '\n== Phase A: software enumeration ==\n'
  check_a1
  check_a2
  check_a3
  check_a4
  check_a5
  check_a6
  check_a7
  check_a8
  check_a9
  check_a10
  check_a11
  check_a12
  check_a13
  check_a14
  check_a15
  check_a16
  check_a17
}

check_b1() {
  if ! ip -br link show eth0 >/dev/null 2>&1; then
    record FAIL B1 "eth0 missing"
    return
  fi
  local carrier
  carrier="$(cat /sys/class/net/eth0/carrier 2>/dev/null || printf '0')"
  if [ "$carrier" != "1" ]; then
    record SKIP B1 "eth0 has no carrier; plug Ethernet for reachability"
    return
  fi
  if ping -c 3 -W 2 8.8.8.8 >/dev/null 2>&1; then
    record PASS B1 "eth0 ping 8.8.8.8 ok"
  else
    record FAIL B1 "eth0 carrier up but ping failed"
  fi
}

check_b2() {
  if ! have_cmd lsusb; then
    record SKIP B2 "lsusb missing"
    return
  fi
  if ls /sys/block 2>/dev/null | grep -Eq '^sd[a-z]$|^nvme'; then
    record PASS B2 "removable/block USB storage detected under /sys/block"
  else
    record SKIP B2 "no USB mass-storage disk; insert a stick and re-run --b2"
  fi
}

check_b3() {
  if [ -z "${SAHA_WIFI_SSID:-}" ] || [ -z "${SAHA_WIFI_PASSWORD:-}" ]; then
    if have_cmd nmcli && nmcli -t -f SSID dev wifi list 2>/dev/null | grep -q .; then
      record SKIP B3 "wifi scan works; set SAHA_WIFI_SSID/PASSWORD to associate"
    else
      record SKIP B3 "set SAHA_WIFI_SSID and SAHA_WIFI_PASSWORD to test association"
    fi
    return
  fi
  if ! have_cmd nmcli; then
    record FAIL B3 "nmcli missing"
    return
  fi
  if nmcli dev wifi connect "$SAHA_WIFI_SSID" password "$SAHA_WIFI_PASSWORD" >/dev/null 2>&1 \
    && ping -c 3 -W 3 8.8.8.8 >/dev/null 2>&1; then
    record PASS B3 "associated to ${SAHA_WIFI_SSID} and ping ok"
  else
    record FAIL B3 "wifi associate or ping failed for ${SAHA_WIFI_SSID}"
  fi
}

check_b4() {
  if ! have_cmd bluetoothctl; then
    record SKIP B4 "bluetoothctl missing"
    return
  fi
  if bluetoothctl power on >/dev/null 2>&1; then
    record PASS B4 "bluetooth controller powered on"
  else
    record FAIL B4 "bluetoothctl power on failed"
  fi
}

check_b5() {
  if ! path_exists_any '/sys/class/drm/*/status'; then
    record FAIL B5 "no DRM connector status"
    return
  fi
  if grep -Rqs '^connected$' /sys/class/drm/*/status 2>/dev/null; then
    record PASS B5 "DRM connector connected"
  else
    record SKIP B5 "HDMI disconnected; attach a display and re-run --b5"
  fi
}

check_b6() {
  if have_cmd speaker-test; then
    if timeout 6 speaker-test -c 2 -t wav -l 1 >/dev/null 2>&1; then
      record PASS B6 "speaker-test completed"
      return
    fi
  fi
  if have_cmd aplay; then
    set +e
    timeout 3 aplay -D default -f S16_LE -r 48000 -c 2 /dev/zero >/dev/null 2>&1
    local status=$?
    set -e
    # 0 = finished, 124 = timeout killed a started playback
    if [ "$status" -eq 0 ] || [ "$status" -eq 124 ]; then
      record PASS B6 "aplay PCM smoke ok"
      return
    fi
  fi
  record SKIP B6 "no speaker-test/aplay path available"
}

check_b7() {
  local can_if
  can_if="$(ip -o link show type can 2>/dev/null | awk -F': ' 'NR==1 {print $2}' | awk '{print $1}')"
  if [ -z "$can_if" ]; then
    record FAIL B7 "no CAN netdev"
    return
  fi
  if ! ip link set "$can_if" up type can bitrate 500000 >/dev/null 2>&1 \
    && ! ip link set "$can_if" up >/dev/null 2>&1; then
    record FAIL B7 "failed to bring ${can_if} up"
    return
  fi
  if have_cmd cansend; then
    cansend "$can_if" 123#DEADBEEF >/dev/null 2>&1 || true
    record ENUM_OK B7 "${can_if} up at 500000; peer/bus needed to confirm TX/RX"
  else
    record ENUM_OK B7 "${can_if} up; cansend missing"
  fi
}

check_b8() {
  record SKIP B8 "run on the host: tio -b 115200 /dev/ttyUSB0 (Micro-USB DEBUG)"
}

check_b9() {
  if ! have_cmd i2cdetect; then
    record SKIP B9 "i2cdetect missing"
    return
  fi
  if ! path_exists_any '/dev/i2c-*'; then
    record FAIL B9 "no I2C adapters"
    return
  fi
  record ENUM_OK B9 "adapters present; attach a device and run i2cdetect -y BUS"
}

run_phase_b() {
  printf '\n== Phase B: accessory checks ==\n'
  want_b B1 && check_b1
  want_b B2 && check_b2
  want_b B3 && check_b3
  want_b B4 && check_b4
  want_b B5 && check_b5
  want_b B6 && check_b6
  want_b B7 && check_b7
  want_b B8 && check_b8
  want_b B9 && check_b9
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --phase-a)
      RUN_PHASE_A=1
      shift
      ;;
    --phase-b)
      RUN_PHASE_B=1
      shift
      ;;
    --all-b)
      RUN_PHASE_B=1
      REQUESTED_B=(B1 B2 B3 B4 B5 B6 B7 B8 B9)
      shift
      ;;
    --b1|--b2|--b3|--b4|--b5|--b6|--b7|--b8|--b9)
      REQUESTED_B+=("B${1#--b}")
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ "${EUID:-$(id -u)}" -ne 0 ]; then
  printf 'WARN: preferred to run as root on the board; continuing\n' >&2
fi

printf 'RDK X5 interface check (%s)\n' "$(hostname 2>/dev/null || printf unknown)"

if [ "$RUN_PHASE_A" -eq 1 ]; then
  run_phase_a
fi

if [ "$RUN_PHASE_B" -eq 1 ] || [ "${#REQUESTED_B[@]}" -gt 0 ]; then
  run_phase_b
fi

printf '\nSummary: PASS=%s ENUM_OK=%s SKIP=%s FAIL=%s\n' \
  "$PASS_COUNT" "$ENUM_COUNT" "$SKIP_COUNT" "$FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
exit 0
