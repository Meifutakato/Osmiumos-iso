#!/usr/bin/env bash
# ============================================================
#  OsmiumOS — fabrique l'image ISO (session d'essai + installation)
#
#  Tourne dans un conteneur Arch Linux en root (GitHub Actions, voir .github/workflows/iso.yml),
#  ou sur un Arch Linux (10 Go libres) :
#      OSMIUMOS_DIR=/root/osmiumos bash construire.sh
#
#  Étapes : outils de fabrication → profil (releng d'Arch + OsmiumOS) → paquets AUR → outils Rust
#  de OsmiumOS → thème → vérification de la configuration Hyprland (Lua) par Hyprland lui-même → ISO
# ============================================================
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Lance ce script en root."; exit 1; }

ICI="$(cd "$(dirname "$0")" && pwd)"
OSMIUMOS="${OSMIUMOS_DIR:-$ICI/osmiumos}"            # dépôt principal (outils, thème)
TRAVAIL="${TRAVAIL:-/tmp/osmium-iso}"               # ~8 Go pendant la fabrication
SORTIE="${SORTIE:-$ICI/sortie}"
CONSTRUCTEUR=constructeur                           # makepkg et cargo refusent root
log() { echo -e "\n\e[1;35m[OsmiumOS]\e[0m $*"; }
[[ -d "$OSMIUMOS/theme-osmiumos" ]] || { echo "Dépôt osmiumos introuvable : $OSMIUMOS (OSMIUMOS_DIR=…)"; exit 1; }

# ------------------------------------------------------------
log "1/8 Outils de fabrication"
pacman-key --init >/dev/null 2>&1 && pacman-key --populate archlinux >/dev/null 2>&1 || true
pacman -Syu --noconfirm --needed archiso git base-devel rust sudo hyprland >/dev/null
id "$CONSTRUCTEUR" >/dev/null 2>&1 || useradd -m "$CONSTRUCTEUR"
echo "$CONSTRUCTEUR ALL=(ALL) NOPASSWD: /usr/bin/pacman" > /etc/sudoers.d/90-constructeur
en_constructeur() { sudo -u "$CONSTRUCTEUR" -H "$@"; }

# ------------------------------------------------------------
log "2/8 Profil : « releng » d'Arch + OsmiumOS"
rm -rf "$TRAVAIL"
mkdir -p "$TRAVAIL" "$SORTIE"
P="$TRAVAIL/profil"
cp -r /usr/share/archiso/configs/releng "$P"
# Réseau : NetworkManager (comme OsmiumOS installé) à la place d'iwd / systemd-networkd
rm -rf "$P/airootfs/etc/systemd/network"
rm -f "$P"/airootfs/etc/systemd/system/multi-user.target.wants/{iwd,systemd-networkd}.service \
      "$P"/airootfs/etc/systemd/system/sockets.target.wants/systemd-networkd.socket \
      "$P"/airootfs/etc/systemd/system/network-online.target.wants/systemd-networkd-wait-online.service
rm -rf "$P/airootfs/etc/systemd/system/systemd-networkd-wait-online.service.d"
# Pas de connexion automatique de root ni du guide d'installation d'Arch
rm -f "$P/airootfs/etc/systemd/system/getty@tty1.service.d/autologin.conf" "$P/airootfs/root/.automated_script.sh" \
      "$P/airootfs/root/.zlogin" "$P/airootfs/usr/local/bin/Installation_guide"
# Ce qui est propre à OsmiumOS (remplace les fichiers de même nom)
cp -rT "$ICI/profil" "$P"
# Menus de démarrage : « OsmiumOS » au lieu de « Arch Linux »
find "$P/efiboot" "$P/syslinux" "$P/grub" -type f \( -name '*.conf' -o -name '*.cfg' \) \
  -exec sed -i 's/Arch Linux install medium/OsmiumOS (essai et installation)/g; s/Arch Linux/OsmiumOS/g' {} +

# ------------------------------------------------------------
log "3/8 Paquets (dépôts officiels, sinon AUR)"
LISTE="$P/packages.x86_64"
sed -i '/^iwd$/d' "$LISTE"
mapfile -t VOULUS < <(grep -hv '^\s*\(#\|$\)' "$ICI/paquets.txt" "$ICI/paquets-aur.txt" | sort -u)
mapfile -t AUR_PERMIS < <(grep -v '^\s*\(#\|$\)' "$ICI/paquets-aur.txt")
A_FABRIQUER=()
for p in "${VOULUS[@]}"; do
  if pacman -Si "$p" >/dev/null 2>&1; then
    echo "$p" >> "$LISTE"
  elif printf '%s\n' "${AUR_PERMIS[@]}" | grep -qx "$p"; then
    A_FABRIQUER+=("$p")
  else
    echo "✗ $p : ni dans les dépôts officiels ni dans paquets-aur.txt"; exit 1
  fi
done
if (( ${#A_FABRIQUER[@]} > 0 )); then
  DEPOT="$TRAVAIL/depot"
  mkdir -p "$DEPOT"; chown "$CONSTRUCTEUR:" "$DEPOT"
  for p in "${A_FABRIQUER[@]}"; do
    echo "   AUR : $p"
    rm -rf "/home/$CONSTRUCTEUR/aur-$p"
    en_constructeur git clone -q "https://aur.archlinux.org/$p.git" "/home/$CONSTRUCTEUR/aur-$p"
    en_constructeur bash -c "cd ~/aur-$p && makepkg -s --noconfirm --needed >/dev/null && cp ./*.pkg.tar.zst '$DEPOT/'"
    echo "$p" >> "$LISTE"
  done
  repo-add -q "$DEPOT/osmiumos-local.db.tar.gz" "$DEPOT"/*.pkg.tar.zst
  # Pour l'installateur (méthode « Télécharger ») : ces paquets ne sont pas dans les dépôts officiels
  install -d "$P/airootfs/usr/local/share/osmium-installateur/aur"
  cp "$DEPOT"/*.pkg.tar.zst "$P/airootfs/usr/local/share/osmium-installateur/aur/"
  printf '\n[osmiumos-local]\nSigLevel = Optional TrustAll\nServer = file://%s\n' "$DEPOT" >> "$P/pacman.conf"
fi
sort -u -o "$LISTE" "$LISTE"
# Pour l'installateur (méthode « Télécharger ») : les paquets officiels voulus par OsmiumOS
install -d "$P/airootfs/usr/local/share/osmium-installateur"
for p in "${VOULUS[@]}"; do
  [[ " ${A_FABRIQUER[*]} " == *" $p "* ]] || echo "$p"
done > "$P/airootfs/usr/local/share/osmium-installateur/paquets.txt"
echo "   $(wc -l < "$LISTE") paquets"

# ------------------------------------------------------------
log "4/8 Outils Rust de OsmiumOS"
BIN="$P/airootfs/usr/local/bin"
CIBLE_CARGO="$TRAVAIL/cargo"
mkdir -p "$CIBLE_CARGO" "$BIN"; chown -R "$CONSTRUCTEUR:" "$CIBLE_CARGO"
for crate in "$OSMIUMOS"/osmium-*/; do
  nom=$(basename "$crate")
  [[ -f "$crate/Cargo.toml" ]] || continue
  rm -rf "$CIBLE_CARGO/$nom"; cp -r "$crate" "$CIBLE_CARGO/$nom"; rm -rf "$CIBLE_CARGO/$nom/target"
  chown -R "$CONSTRUCTEUR:" "$CIBLE_CARGO/$nom"
  en_constructeur bash -c "cd '$CIBLE_CARGO/$nom' && cargo build --release -q"
  install -m755 "$CIBLE_CARGO/$nom/target/release/$nom" "$BIN/$nom"
  echo "   $nom"
done
# Anciens noms des outils de jeu
for ancien in osmium-shadowrecord osmium-reprise osmium-clip-sauve osmium-gameresume; do ln -sf osmium-jeux "$BIN/$ancien"; done
# Données et fichiers système des outils
install -Dm644 "$OSMIUMOS/osmium-defender/donnees/attack-reduit.json" "$P/airootfs/usr/local/share/osmium-defender/attack-reduit.json"
install -Dm644 "$OSMIUMOS/osmium-defender/systeme/osmium-defender.desktop" "$P/airootfs/usr/local/share/applications/osmium-defender.desktop"
install -Dm644 "$OSMIUMOS/osmium-safezone/systeme/osmium-safezone.service" "$P/airootfs/etc/systemd/user/osmium-safezone.service"
install -Dm644 "$OSMIUMOS/osmium-safezone/systeme/osmium-safezone.timer" "$P/airootfs/etc/systemd/user/osmium-safezone.timer"

# ------------------------------------------------------------
log "5/8 Thème OsmiumOS (pour chaque nouvel utilisateur : /etc/skel)"
T="$OSMIUMOS/theme-osmiumos"
SKEL="$P/airootfs/etc/skel"
mkdir -p "$SKEL/.config"
cp -r "$T"/config/* "$SKEL/.config/"
rm -f "$SKEL/.config/hypr/hyprland.conf"         # Hyprland récent : seulement hyprland.lua
install -Dm644 "$OSMIUMOS/osmium-defender/systeme/defender.lua" "$SKEL/.config/hypr/modules/defender.lua"
# Réglages de la machine : vrai PC, effets complets (écrits par osmium-hypr, comme sur OsmiumOS installé)
HOME="$SKEL" XDG_CONFIG_HOME="$SKEL/.config" "$BIN/osmium-hypr" machine --pc >/dev/null
HOME="$SKEL" XDG_CONFIG_HOME="$SKEL/.config" "$BIN/osmium-hypr" effets complets >/dev/null
cat > "$SKEL/.config/hypr/perso.lua" <<'EOF'
-- Tes réglages personnels Hyprland (Lua). OsmiumOS ne touche jamais à ce fichier.
-- Exemples : osmium.lancer("SUPER + B", "firefox") · hl.config({ general = { gaps_out = 8 } })
EOF
install -Dm644 "$T/fonds/galaxie-osmium.jpg" "$P/airootfs/usr/share/backgrounds/osmiumos/galaxie-osmium.jpg"
install -Dm644 "$T/logos/osmiumos.svg" "$P/airootfs/usr/share/pixmaps/osmiumos.svg"
install -Dm644 "$T/logos/osmiumos.svg" "$P/airootfs/usr/share/icons/hicolor/scalable/apps/osmiumos.svg"
install -Dm644 "$T/config/quickshell/icones/parametres.svg" "$P/airootfs/usr/share/pixmaps/osmiumos-parametres.svg"
install -Dm644 "$T/config/quickshell/icones/lecteur.svg" "$P/airootfs/usr/share/pixmaps/osmiumos-lecteur.svg"
install -d "$P/airootfs/usr/share/sddm/themes/osmiumos"
install -m644 "$T"/sddm/osmiumos/* "$P/airootfs/usr/share/sddm/themes/osmiumos/"
cp "$ICI"/applications/*.desktop "$P/airootfs/usr/local/share/applications/"

# ------------------------------------------------------------
log "6/8 Vérification de la configuration Hyprland (Lua) par Hyprland $(pacman -Q hyprland | cut -d' ' -f2)"
VERIF=$(mktemp -d /tmp/osmium-verif-XXXXXX)
cp -r "$SKEL/.config" "$VERIF/"
mkdir -p "$VERIF/run"; chmod 700 "$VERIF/run"
chown -R "$CONSTRUCTEUR:" "$VERIF"
if sudo -u "$CONSTRUCTEUR" env HOME="$VERIF" XDG_CONFIG_HOME="$VERIF/.config" XDG_RUNTIME_DIR="$VERIF/run" \
     Hyprland --verify-config --config "$VERIF/.config/hypr/hyprland.lua" > "$TRAVAIL/verification.txt" 2>&1; then
  echo "   ✓ configuration acceptée"
else
  echo "   ✗ Hyprland refuse la configuration OsmiumOS :"
  sed 's/^/     /' "$TRAVAIL/verification.txt" | tail -n 40
  exit 1
fi
rm -rf "$VERIF"

# ------------------------------------------------------------
log "7/8 Image ISO (mkarchiso, 20 à 40 min)"
mkarchiso -v -r -w "$TRAVAIL/w" -o "$SORTIE" "$P"

# ------------------------------------------------------------
log "8/8 Terminé"
ls -lh "$SORTIE"/*.iso
( cd "$SORTIE" && sha256sum ./*.iso > SHA256SUMS )
cp "$TRAVAIL/verification.txt" "$SORTIE/verification-hyprland.txt"
pacman -Q hyprland quickshell 2>/dev/null > "$SORTIE/versions.txt" || true
