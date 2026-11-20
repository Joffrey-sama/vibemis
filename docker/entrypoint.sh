#!/usr/bin/env bash
set -euo pipefail

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp/runtime-vibemis}"
export VDPAU_DRIVER_PATH="${VDPAU_DRIVER_PATH:-/tmp}"

VIBEMIS_CONF_DIR="${VIBEMIS_CONF_DIR:-/root/.config/Vibemis Project}"
VIBEMIS_CONF_FILE="${VIBEMIS_CONF_DIR}/Vibemis.conf"
VIBEMIS_CONFIG_INI="${VIBEMIS_CONFIG_INI:-/etc/vibemis/config.ini}"
VIBEMIS_SECRET_INI="${VIBEMIS_SECRET_INI:-/etc/vibemis/secret.ini}"

prepare_runtime_dir() {
  mkdir -p "${XDG_RUNTIME_DIR}"
  chmod 0700 "${XDG_RUNTIME_DIR}"
}

configure_alsa() {
  if [[ -n "${ALSA_CARD:-}" && -n "${ALSA_DEVICE:-}" ]]; then
    cat <<EOF > /etc/asound.conf
pcm.!default {
    type plug
    slave.pcm {
        type hw
        card ${ALSA_CARD}
        device ${ALSA_DEVICE}
    }
}
ctl.!default {
    type hw
    card ${ALSA_CARD}
}
EOF
  fi
}

merge_vibemis_config() {
  mkdir -p "${VIBEMIS_CONF_DIR}"
  python3 /usr/local/bin/merge_ini.py \
    "${VIBEMIS_CONF_FILE}" \
    "${VIBEMIS_CONFIG_INI}" \
    "${VIBEMIS_SECRET_INI}"
}

wait_for_display() {
  while ! grep -q "^connected$" /sys/class/drm/card*-*/status 2>/dev/null; do
    echo "[vibemis-kiosk] No active HDMI/DP display detected (TV off or unplugged). Waiting 5s..."
    sleep 5
  done
}

detect_drm_device() {
  local intel_card="/dev/dri/card0"
  local status_file
  for status_file in /sys/class/drm/card*-HDMI-*/status; do
    if [[ -f "$status_file" ]] && grep -q "^connected$" "$status_file"; then
      local card_name
      card_name=$(basename "$(dirname "$status_file")" | cut -d'-' -f1)
      intel_card="/dev/dri/${card_name}"
      break
    fi
  done
  echo "${intel_card}"
}

configure_xorg_and_openbox() {
  local drm_device="$1"
  mkdir -p /etc/X11/xorg.conf.d /root/.config/openbox

  cat <<EOF > /etc/X11/xorg.conf.d/20-intel-kms.conf
Section "Device"
    Identifier "IntelGPU"
    Driver "modesetting"
    Option "kmsdev" "${drm_device}"
    Option "VariableRefresh" "true"
EndSection
EOF

  cat <<'EOF' > /root/.config/openbox/rc.xml
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <applications>
    <application type="normal">
      <decor>no</decor>
      <maximized>true</maximized>
      <fullscreen>yes</fullscreen>
    </application>
  </applications>
</openbox_config>
EOF
}

write_xinitrc() {
  cat <<'EOF' > /tmp/xinitrc.sh
#!/usr/bin/env bash
xset s off
xset -dpms
xset s noblank
openbox &
if [[ "${VIBEMIS_AUTO_OPEN_HOST:-false}" == "true" ]]; then
  (sleep 4 && xdotool key Return) &
fi
exec /opt/vibemis/AppRun "$@"
EOF
  chmod +x /tmp/xinitrc.sh
}

run_self_test() {
  echo "[vibemis-kiosk] Running headless self-test via Xvfb..."
  python3 /usr/local/bin/merge_ini.py --self-test
  exec xvfb-run -a /opt/vibemis/AppRun --help
}

main() {
  prepare_runtime_dir
  configure_alsa
  merge_vibemis_config

  if [[ "${1:-}" == "--self-test" ]] || [[ ! -d /dev/dri ]]; then
    run_self_test
  fi

  wait_for_display

  export QT_QPA_PLATFORM=xcb
  export DISPLAY=:0

  local drm_device
  drm_device="$(detect_drm_device)"
  echo "[vibemis-kiosk] Active display detected (${drm_device}). Starting Xorg + Openbox + Vibemis..."

  configure_xorg_and_openbox "${drm_device}"
  write_xinitrc

  rm -f /tmp/.X0-lock /tmp/.X11-unix/X0
  chvt 7 || true

  exec xinit /tmp/xinitrc.sh "$@" -- :0 vt7 -nolisten tcp -noreset -keeptty
}

main "$@"
