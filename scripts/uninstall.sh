#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "ERROR: This script must be run with sudo." >&2
  exit 1
fi

if [ -z "${SUDO_USER:-}" ]; then
  echo "ERROR: Could not determine the original user. Please run with sudo from a regular user account." >&2
  exit 1
fi

PREFIX="${PREFIX:-/usr/local}"
REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
LOCAL_SHARE="$REAL_HOME/.local/share/caelestia-grub"
GRUB_THEME_DIR="/boot/grub/themes/caelestia-nexus"
DEPLOY_SCRIPT="$PREFIX/bin/caelestia-grub-deploy"

echo "============================================================"
echo "         Uninstalling Caelestia Nexus GRUB Theme"
echo "============================================================"

echo "1. Removing GRUB theme files..."
rm -rf "$GRUB_THEME_DIR"

echo "2. Removing deployment hooks and scripts..."
rm -f "$DEPLOY_SCRIPT"
rm -f /etc/sudoers.d/caelestia-grub-sync
rm -rf "$LOCAL_SHARE"

echo "3. Removing Caelestia CLI postHook..."
CLI_JSON="$REAL_HOME/.config/caelestia/cli.json"
# We escape the prefix since it was embedded in the hook command
HOOK_CMD="export PREFIX=$PREFIX; bash $LOCAL_SHARE/scripts/sync.sh"

sudo -u "$SUDO_USER" python3 -c "
import json, os
path = '$CLI_JSON'
if os.path.exists(path):
    with open(path) as f:
        data = json.load(f)
    
    changed = False
    for section in ['wallpaper', 'theme']:
        if section in data and 'postHook' in data[section]:
            hooks = data[section]['postHook'].split(' && ')
            if '$HOOK_CMD' in hooks:
                hooks.remove('$HOOK_CMD')
                if hooks:
                    data[section]['postHook'] = ' && '.join(hooks)
                else:
                    del data[section]['postHook']
                changed = True

    if changed:
        with open(path, 'w') as f:
            json.dump(data, f, indent=4)
"

echo "4. Reverting GRUB configuration..."
if grep -q "^GRUB_THEME=\"$GRUB_THEME_DIR" /etc/default/grub; then
    sed -i "s|^GRUB_THEME=\"$GRUB_THEME_DIR.*|#GRUB_THEME=|" /etc/default/grub
    grub-mkconfig -o /boot/grub/grub.cfg
    echo "✓ GRUB configuration reverted"
else
    echo "✓ No changes needed in /etc/default/grub"
fi

echo ""
echo "✅ Uninstallation Complete."
