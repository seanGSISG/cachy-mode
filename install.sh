#!/usr/bin/env bash
# Install/upgrade cachy-mode: CLI symlink, user unit, Plasma widget pinned in the
# system tray. Idempotent. plasmashell is stopped around the package swap:
# a running shell drops tray entries whose package briefly disappears.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
ID=me.lsdmt.cachymode
RC=~/.config/plasma-org.kde.plasma.desktop-appletsrc

mkdir -p ~/.local/bin ~/.config/systemd/user
ln -sfn "$here/bin/cachy-mode" ~/.local/bin/cachy-mode
ln -sfn "$here/systemd/cachy-mode-auto.service" ~/.config/systemd/user/cachy-mode-auto.service
systemctl --user daemon-reload

systemctl --user stop plasma-plasmashell
cp -a "$RC" "$RC.bak-cachymode"
kpackagetool6 -t Plasma/Applet -u "$here/plasmoid" 2>/dev/null || kpackagetool6 -t Plasma/Applet -i "$here/plasmoid"

# The system tray lives in an applet whose group holds plugin=org.kde.plasma.systemtray
tray=$(grep -B8 '^plugin=org.kde.plasma.systemtray$' "$RC" | grep -oP '^\[Containments\]\[\K[0-9]+\]\[Applets\]\[[0-9]+(?=\]$)' | tail -1)
if [[ -n $tray ]]; then
  G=(--file "$RC" --group Containments --group "${tray%%]*}" --group Applets --group "${tray##*[}" --group General)
  for k in extraItems shownItems; do
    cur=$(kreadconfig6 "${G[@]}" --key "$k")
    [[ ",$cur," == *",$ID,"* ]] || kwriteconfig6 "${G[@]}" --key "$k" "${cur:+$cur,}$ID"
  done
else
  echo "warning: system tray not found; add Cachy Mode via System Tray settings → Entries" >&2
fi
systemctl --user start plasma-plasmashell
echo "Installed cachy-mode (tray: ${tray:-not found})."
