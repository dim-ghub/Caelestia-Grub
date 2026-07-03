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

# Fallback prefix if not supplied by pkgit
PREFIX="${PREFIX:-/usr/local}"

REAL_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

LOCAL_SHARE="$REAL_HOME/.local/share/caelestia-grub"
GRUB_THEME_DIR="/boot/grub/themes/caelestia-nexus"
DEPLOY_SCRIPT="$PREFIX/bin/caelestia-grub-deploy"

echo "============================================================"
echo "          Installing Caelestia Nexus GRUB Theme"
echo "============================================================"

echo "1. Copying files to local share ($LOCAL_SHARE)..."
sudo -u "$SUDO_USER" mkdir -p "$LOCAL_SHARE/src"
sudo -u "$SUDO_USER" mkdir -p "$LOCAL_SHARE/theme"
sudo -u "$SUDO_USER" mkdir -p "$LOCAL_SHARE/scripts"

sudo -u "$SUDO_USER" cp -r "$PROJECT_ROOT/src/"* "$LOCAL_SHARE/src/"
sudo -u "$SUDO_USER" cp -r "$PROJECT_ROOT/theme/"* "$LOCAL_SHARE/theme/"
sudo -u "$SUDO_USER" cp "$PROJECT_ROOT/scripts/sync.sh" "$LOCAL_SHARE/scripts/"
sudo -u "$SUDO_USER" chmod +x "$LOCAL_SHARE/scripts/sync.sh"
echo "✓ Local files staged"

echo "2. Creating deployment hooks in $PREFIX/bin..."
mkdir -p "$PREFIX/bin"
cat <<EOF > "$DEPLOY_SCRIPT"
#!/usr/bin/env bash
set -e
mkdir -p "$GRUB_THEME_DIR"
cp -r "$LOCAL_SHARE/theme/"* "$GRUB_THEME_DIR/"
EOF
chmod +x "$DEPLOY_SCRIPT"

# Configure passwordless sudo for the deploy script
echo "$SUDO_USER ALL=(root) NOPASSWD: $DEPLOY_SCRIPT" > /etc/sudoers.d/caelestia-grub-sync
chmod 440 /etc/sudoers.d/caelestia-grub-sync
echo "✓ Deploy script and sudoers drop-in created"

echo "3. Running initial generation and sync..."
# Export PREFIX so sync.sh can find the deploy script
sudo -u "$SUDO_USER" env PREFIX="$PREFIX" bash "$LOCAL_SHARE/scripts/sync.sh"
echo "✓ Initial sync completed"

echo "4. Updating GRUB configuration..."
if grep -q "^GRUB_THEME=" /etc/default/grub; then
    sed -i 's|^GRUB_THEME=.*|GRUB_THEME="/boot/grub/themes/caelestia-nexus/theme.txt"|' /etc/default/grub
else
    echo 'GRUB_THEME="/boot/grub/themes/caelestia-nexus/theme.txt"' >> /etc/default/grub
fi
grub-mkconfig -o /boot/grub/grub.cfg
echo "✓ GRUB updated"

echo "5. Configuring Caelestia CLI postHook..."
CLI_JSON="$REAL_HOME/.config/caelestia/cli.json"
# We need to export PREFIX when calling the sync script via postHook
HOOK_CMD="export PREFIX=$PREFIX; bash $LOCAL_SHARE/scripts/sync.sh"

sudo -u "$SUDO_USER" python3 -c "
import json, os
path = '$CLI_JSON'
if not os.path.exists(path):
    data = {}
else:
    try:
        with open(path) as f:
            data = json.load(f)
    except:
        data = {}

for section in ['wallpaper', 'theme']:
    if section not in data:
        data[section] = {}
    if 'postHook' not in data[section]:
        data[section]['postHook'] = '$HOOK_CMD'
    else:
        if '$HOOK_CMD' not in data[section]['postHook']:
            data[section]['postHook'] += ' && $HOOK_CMD'

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, 'w') as f:
    json.dump(data, f, indent=4)
"
echo "✓ Caelestia CLI hooked"

echo ""
echo "============================================================"
echo "✅ Installation Complete!"
echo "The theme has been applied to GRUB."
echo "Whenever you change your theme in Caelestia, the GRUB background"
echo "and assets will automatically regenerate and sync in the background!"
echo "============================================================"
