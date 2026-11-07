#!/usr/bin/env bash
# shellcheck disable=SC2034
# OsmiumOS — profil archiso (part du profil « releng » d'Arch, voir construire.sh)

iso_name="osmiumos"
iso_label="OSMIUMOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="OsmiumOS <https://github.com/Meifutakato/osmiumos-iso>"
iso_application="OsmiumOS — essai et installation"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
# xz : l'image la plus petite possible (une ISO publiée sur GitHub doit rester sous 2 Go)
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/sudoers.d/10-osmium-live"]="0:0:440"
  ["/root"]="0:0:750"
  ["/usr/local/bin/osmium-live-utilisateur"]="0:0:755"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
)
