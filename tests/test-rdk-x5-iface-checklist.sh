#!/usr/bin/env bash
# Contract test: RDK X5 interface checklist and on-target helper stay in sync.
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
CHECKLIST="$ROOT_DIR/tests/rdk-x5-iface-checklist.md"
HELPER="$ROOT_DIR/tests/check-rdk-x5-iface.sh"
HARDWARE_GUIDE="$ROOT_DIR/docs/hardware/rdk-x5.md"
AGENTS="$ROOT_DIR/AGENTS.md"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

[ -f "$CHECKLIST" ] || fail "missing $CHECKLIST"
[ -f "$HELPER" ] || fail "missing $HELPER"
[ -x "$HELPER" ] || fail "helper must be executable: $HELPER"
bash -n "$HELPER"

for id in A1 A2 A3 A4 A5 A6 A7 A8 A9 A10 A11 A12 A13 A14 A15 A16 A17 \
  B1 B2 B3 B4 B5 B6 B7 B8 B9 C1 C2 C3 C4; do
  grep -Eq "^\\| ${id} " "$CHECKLIST" || fail "checklist missing row for ${id}"
done

for id in A1 A2 A3 A4 A5 A6 A7 A8 A9 A10 A11 A12 A13 A14 A15 A16 A17 \
  B1 B2 B3 B4 B5 B6 B7 B8 B9; do
  grep -Fq "$id" "$HELPER" || fail "helper missing ${id}"
done

grep -Fq 'SAHA_WIFI_SSID' "$HELPER" || fail "helper must document Wi-Fi env vars"
grep -Fq '192.168.128.10' "$CHECKLIST" || fail "checklist must document USB gadget login"
grep -Fq 'check-rdk-x5-iface.sh' "$CHECKLIST" || fail "checklist must point at the helper"

help_output="$("$HELPER" --help)"
[[ "$help_output" == *"--phase-a"* ]] || fail "helper --help must mention --phase-a"
[[ "$help_output" == *"--phase-b"* ]] || fail "helper --help must mention --phase-b"
[[ "$help_output" == *"SAHA_WIFI_SSID"* ]] || fail "helper --help must mention SAHA_WIFI_SSID"

grep -Fq 'rdk-x5-iface-checklist.md' "$HARDWARE_GUIDE" ||
  fail "hardware guide must link the interface checklist"
grep -Fq 'check-rdk-x5-iface.sh' "$AGENTS" ||
  fail "AGENTS.md must mention the on-target interface helper"

printf 'PASS: RDK X5 interface checklist contract\n'
