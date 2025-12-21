#!/usr/bin/env sh

set -eux -o pipefail

OS_URL="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/aarch64/alpine-rpi-3.23.2-aarch64.img.gz"
HEADLESS_OVERLAY_URL="https://github.com/macmpi/alpine-linux-headless-bootstrap/raw/469ee440e7d394cca0976c78f357e7a0e1c82cc4/headless.apkovl.tar.gz"
OS_FILE="alpine-rpi-3.23.2-aarch64.img.gz"

download-img-file() {
  if ! [ -f "tmp/alpine-rpi-3.23.2-aarch64.img" ]; then
    wget --show-progress "$OS_URL" -O tmp/alpine-rpi-3.23.2-aarch64.img.gz
    gunzip tmp/alpine-rpi-3.23.2-aarch64.img.gz
  fi

  if ! [ -f "tmp/headless.apkovl.tar.gz" ]; then
    wget --show-progress "$HEADLESS_OVERLAY_URL" -O tmp/headless.apkovl.tar.gz
  fi
}

create-image() {
  mkdir -p tmp/image
  download-img-file
  mount-image
  sudo cp -f usercfg.txt alpine-setup-config tmp/headless.apkovl.tar.gz wpa_supplicant.conf unattended.sh -t tmp/image unmount-image
}

unmount-image() {
  sudo sync
  sudo umount tmp/image || true
  sudo losetup -d /dev/loop0 || true
}

mount-image() {
  sudo losetup --find --show --partscan tmp/alpine-rpi-3.23.2-aarch64.img || true
  sudo mount -o loop /dev/loop0p1 tmp/image
}

write-image() {
  sudo rpi-imager --cli 'tmp/alpine-rpi-3.23.2-aarch64.img' /dev/sda
}

_run() {
  ssh -t root@192.168.0.130 "$@"
}
_runuser() {
  ssh -t bingobango@192.168.0.130 "$@"
}

setup-via-ssh() {
  _run "setup-alpine -ef /media/mmcblk0p1/alpine-setup-config; setup-interfaces; setup-sshd"
  _run "mount /dev/mmcblk0p1 /media/mmcblk0p1/"
  scp -O ./usercfg.txt ./wpa_supplicant.conf root@192.168.0.130:/media/mmcblk0p1
  _run "sync; umount -f /media/mmcblk0p1/"
}

cmd="$1"; shift 1;
case "$cmd" in
  configure) cd ansible && ansible-playbook -i host.ini playbook/system.yml --ask-become-pass ;;
  create-image) create-image ;;
  mount-image) mount-image ;;
  unmount-image) unmount-image ;;
  write-image) write-image ;;
  setup-via-ssh) setup-via-ssh ;;
  shell) _runuser ;;
  run) _runuser "$@" ;;
  runroot) _run "$@" ;;
  config-sync) config-sync ;;
esac

