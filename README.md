# NexusOS — image ISO

Une clé USB qui démarre sur le bureau NexusOS (Hyprland + Quickshell), pour l'essayer sans rien installer,
puis l'installer. Fabriquée automatiquement par GitHub Actions à partir du dépôt
nexusos (dépôt privé : outils Rust, thème) et du profil « releng » d'Arch Linux.

## Télécharger

- **Version publiée** : onglet **Releases** (sans compte GitHub).
- **Dernière fabrication** : onglet **Actions › Image ISO** › la dernière exécution › *Artifacts* (compte GitHub, 7 jours).

Écrire l'ISO sur une clé : [Ventoy](https://www.ventoy.net), Rufus (mode « image DD ») ou
`sudo dd if=nexusos-….iso of=/dev/sdX bs=4M status=progress oflag=sync`.
Si l'ISO est découpée (`.part00`, `.part01`) : `cat nexusos-….iso.part* > nexusos-….iso`.

## Ce qu'il y a dedans

- Bureau NexusOS complet, en français, clavier AZERTY : barre, îlot, menu, Paramètres, gestionnaire de tâches.
- Outils NexusOS compilés : nexus-jeux, nexus-safezone, nexus-defender, nexus-gardien, nexus-cloison, nexus-rempart,
  nexus-veille, nexus-taches, nexus-ilot, nexus-agents, nexus-hypr.
- Configuration Hyprland en Lua, **vérifiée par Hyprland lui-même** pendant la fabrication
  (`verification-hyprland.txt` à côté de l'ISO).
- Pas dans l'image (trop lourds, installés ensuite avec Internet) : Steam, Wine, Proton, modèles d'IA.

## Fabriquer soi-même

Sur un Arch Linux, en root, avec ~10 Go libres :
```
git clone https://github.com/Meifutakato/nexusos-iso && cd nexusos-iso
git clone https://github.com/Meifutakato/nexusos   # privé : accès nécessaire
bash construire.sh          # → sortie/nexusos-AAAA.MM.JJ-x86_64.iso
```

| Fichier | Rôle |
|---|---|
| `construire.sh` | toute la fabrication (8 étapes) |
| `paquets.txt` / `paquets-aur.txt` | paquets de l'image ; ceux absents des dépôts officiels viennent de l'AUR |
| `profil/` | ce qui change par rapport au profil « releng » d'Arch (session d'essai, langue, réseau) |
| `applications/` | entrées de menu NexusOS |

## À venir

L'installateur graphique « Installer NexusOS » (sur un disque USB d'abord ; à côté de Windows ensuite).
