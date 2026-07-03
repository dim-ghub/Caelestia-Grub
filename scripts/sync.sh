#!/usr/bin/env bash
set -euo pipefail

# This script is called by the Caelestia CLI postHook.
# It runs as the regular user.

PREFIX="${PREFIX:-/usr/local}"
LOCAL_SHARE="$HOME/.local/share/caelestia-grub"
DEPLOY_SCRIPT="$PREFIX/bin/caelestia-grub-deploy"

echo "Syncing Caelestia GRUB theme..."

# 1. Regenerate assets in the user's local directory
if [ -f "$LOCAL_SHARE/src/generate.py" ]; then
    echo "Regenerating assets..."
    cd "$LOCAL_SHARE/src"
    
    # We must ensure that a display server is running or we force offscreen (handled in python)
    python3 generate.py
    echo "✓ Assets regenerated locally"
else
    echo "✗ Error: generate.py not found in $LOCAL_SHARE/src"
    exit 1
fi

# 2. Deploy to /boot/grub using the passwordless sudo helper
if [ -f "$DEPLOY_SCRIPT" ]; then
    echo "Deploying to /boot/grub..."
    sudo "$DEPLOY_SCRIPT"
    echo "✓ Deployment complete"
else
    echo "✗ Error: caelestia-grub-deploy helper not found at $DEPLOY_SCRIPT. Is the theme properly installed?"
    exit 1
fi

echo "✓ Sync complete"
