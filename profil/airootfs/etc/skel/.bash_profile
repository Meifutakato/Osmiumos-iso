# NexusOS — le bureau démarre tout seul sur la console 1
[[ -f ~/.bashrc ]] && . ~/.bashrc
if [[ -z "$WAYLAND_DISPLAY" && "$(tty)" == /dev/tty1 ]]; then
  if command -v start-hyprland >/dev/null; then exec start-hyprland; else exec Hyprland; fi
fi
