#!/usr/bin/env bash
set -uo pipefail
source "$(dirname "$(readlink -f "$0")")/_lib.sh"
need_root "$@"
need_setup
# Soal 18 — VG research dari file loop: besar (2 GiB) / kecil (1 GiB) / tidak ada.
setup_vg() { # host size_mb(0 = tanpa VG)
  { size="$2"; rvars size; cat <<'EOS'
set -e
command -v lvm >/dev/null || dnf -y -q install lvm2 >/dev/null
for m in $(findmnt -rn -o TARGET -S /dev/research/data 2>/dev/null); do umount "$m"; done
sed -i '\#/dev/research/data#d;\#/dev/mapper/research-data#d' /etc/fstab
if vgs research >/dev/null 2>&1; then
  pvs="$(pvs --noheadings -o pv_name -S vg_name=research | xargs)"
  vgremove -f research >/dev/null
  for p in $pvs; do pvremove -ff -y "$p" >/dev/null 2>&1 || true; done
fi
systemctl disable --now ex294-research-loop >/dev/null 2>&1 || true
for l in $(losetup -j /var/lib/ex294/research.img -O NAME -n 2>/dev/null); do
  lvmdevices --deldev "$l" >/dev/null 2>&1 || true; losetup -d "$l"; done
rm -f /var/lib/ex294/research.img /etc/systemd/system/ex294-research-loop.service
systemctl daemon-reload
[ "$size" -gt 0 ] || exit 0
mkdir -p /var/lib/ex294
fallocate -l "${size}M" /var/lib/ex294/research.img
cat > /etc/systemd/system/ex294-research-loop.service <<'UNIT'
[Unit]
Description=EX294 practice: loop device for VG research
DefaultDependencies=no
After=systemd-udev-settle.service local-fs-pre.target
Before=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/sh -c 'losetup -j /var/lib/ex294/research.img | grep -q . || losetup -f /var/lib/ex294/research.img; sleep 1; vgchange -ay research'
ExecStop=/bin/sh -c 'vgchange -an research; losetup -j /var/lib/ex294/research.img -O NAME -n | xargs -r -n1 losetup -d'

[Install]
WantedBy=local-fs.target
UNIT
systemctl daemon-reload
losetup -f /var/lib/ex294/research.img
dev="$(losetup -j /var/lib/ex294/research.img -O NAME -n | head -1)"
pvcreate -y "$dev" >/dev/null
vgcreate research "$dev" >/dev/null
systemctl enable ex294-research-loop >/dev/null 2>&1
EOS
  } | rscript "$1" && log "$1: VG research ${2} MiB" || warn "$1: gagal menyiapkan VG"
}
for h in $ALL_HOSTS; do
  if in_list "$h" "$RESEARCH_BIG_HOSTS"; then setup_vg "$h" 2048
  elif in_list "$h" "$RESEARCH_SMALL_HOSTS"; then setup_vg "$h" 1024
  else setup_vg "$h" 0; log "$h: tanpa VG research"; fi
done
log "Soal 18 siap"
