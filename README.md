# OsmiumOS — image ISO

Une clé USB qui démarre sur le bureau OsmiumOS (Hyprland + Quickshell), pour l'essayer sans rien installer,
puis l'installer. Fabriquée automatiquement par GitHub Actions à partir du dépôt
osmiumos (dépôt privé : outils Rust, thème) et du profil « releng » d'Arch Linux.

## Télécharger

- **Version publiée** : onglet **Releases** (sans compte GitHub).
- **Dernière fabrication** : onglet **Actions › Image ISO** › la dernière exécution › *Artifacts* (compte GitHub, 7 jours).

Écrire l'ISO sur une clé : [Ventoy](https://www.ventoy.net), Rufus (mode « image DD ») ou
`sudo dd if=osmiumos-….iso of=/dev/sdX bs=4M status=progress oflag=sync`.
Si l'ISO est découpée (`.part00`, `.part01`) : `cat osmiumos-….iso.part* > osmiumos-….iso`.

## Ce qu'il y a dedans

- Bureau OsmiumOS complet, en français, clavier AZERTY : barre, îlot, menu, Paramètres, gestionnaire de tâches.
- Outils OsmiumOS compilés : osmium-jeux, osmium-safezone, osmium-defender, osmium-gardien, osmium-cloison, osmium-rempart,
  osmium-veille, osmium-taches, osmium-ilot, osmium-agents, osmium-hypr.
- Configuration Hyprland en Lua, **vérifiée par Hyprland lui-même** pendant la fabrication
  (`verification-hyprland.txt` à côté de l'ISO).
- Pas dans l'image (trop lourds, installés ensuite avec Internet) : Steam, Wine, Proton, modèles d'IA.

## Fabriquer soi-même

Sur un Arch Linux, en root, avec ~10 Go libres :
```
git clone https://github.com/Meifutakato/osmiumos-iso && cd osmiumos-iso
git clone https://github.com/Meifutakato/osmiumos   # privé : accès nécessaire
bash construire.sh          # → sortie/osmiumos-AAAA.MM.JJ-x86_64.iso
```

| Fichier | Rôle |
|---|---|
| `construire.sh` | toute la fabrication (8 étapes) |
| `paquets.txt` / `paquets-aur.txt` | paquets de l'image ; ceux absents des dépôts officiels viennent de l'AUR |
| `profil/` | ce qui change par rapport au profil « releng » d'Arch (session d'essai, langue, réseau) |
| `applications/` | entrées de menu OsmiumOS |

## À venir

L'installateur graphique « Installer OsmiumOS » (sur un disque USB d'abord ; à côté de Windows ensuite).
