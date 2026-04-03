#!/bin/bash
# TrueNAS SCALE Hetzner Cloud Provisioning Script
#
# Provisions a Hetzner Cloud CX23 server with the TrueNAS SCALE ISO attached.
#
# NOTE: CX23 (cost-optimized) does NOT support Hetzner Volumes — volume attach
# always fails with unknown_error. The ZFS data pool is created from a sparse
# image file on the boot disk instead (see configure-base.sh). This is fully
# supported by ZFS and works fine for a test/repro environment.
#
# Usage: ./provision.sh
#
# Prerequisites: hcloud CLI, jq, SSH key "steve@workstation" in Hetzner account
#
# Configuration:
SERVER_NAME="truenas-repro"
SERVER_TYPE="cx23"
LOCATION="nbg1"        # CX23 available in fsn1/nbg1/hel1; use whichever is open
SSH_KEY="steve@workstation"
IMAGE="debian-12"      # Used for initial creation only; TrueNAS ISO overwrites on boot
TRUENAS_ISO="TrueNAS-SCALE-25.04.2.5.iso"

set -euo pipefail

echo "=== TrueNAS SCALE Hetzner Cloud Provisioning ==="
echo ""

# --- Server ---
if hcloud server describe "$SERVER_NAME" &>/dev/null; then
    echo "✓ Server '$SERVER_NAME' already exists, skipping creation"
else
    echo "→ Creating server '$SERVER_NAME' (type: $SERVER_TYPE, location: $LOCATION)..."
    hcloud server create \
        --name "$SERVER_NAME" \
        --type "$SERVER_TYPE" \
        --image "$IMAGE" \
        --location "$LOCATION" \
        --ssh-key "$SSH_KEY"
    echo "✓ Server created"
fi

# --- ISO ---
CURRENT_ISO=$(hcloud server describe "$SERVER_NAME" -o json | jq -r '.iso.name // empty')
if [ "$CURRENT_ISO" = "$TRUENAS_ISO" ]; then
    echo "✓ TrueNAS ISO already attached"
else
    echo "→ Attaching TrueNAS ISO '$TRUENAS_ISO'..."
    hcloud server attach-iso "$SERVER_NAME" "$TRUENAS_ISO"
    echo "✓ ISO attached"
fi

# --- Reboot to boot from ISO ---
echo "→ Rebooting server to boot from TrueNAS installer..."
hcloud server reboot "$SERVER_NAME"
echo "✓ Server rebooted"

echo ""
echo "=== Provisioning Complete ==="
echo ""
SERVER_INFO=$(hcloud server describe "$SERVER_NAME" -o json)
echo "  Name:   $SERVER_NAME"
echo "  Type:   $SERVER_TYPE"
echo "  Status: $(echo "$SERVER_INFO" | jq -r '.status')"
echo "  IPv4:   $(echo "$SERVER_INFO" | jq -r '.public_net.ipv4.ip')"
echo "  IPv6:   $(echo "$SERVER_INFO" | jq -r '.public_net.ipv6.ip')"
echo "  ISO:    $TRUENAS_ISO"
echo ""
echo "Next: open https://console.hetzner.cloud → Servers → $SERVER_NAME → Console"
echo "      Follow docs/truenas-install.md to complete installation."
echo ""
echo "NOTE: No Hetzner Volume created. ZFS data pool will be a sparse image file"
echo "      on the boot disk (~15GB). See configure-base.sh for details."
