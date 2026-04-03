#!/bin/bash
# TrueNAS SCALE Hetzner Cloud Provisioning Script
# 
# This script provisions a Hetzner Cloud server with TrueNAS SCALE ISO.
# It creates a CX23 server, attaches a 10GB data volume, and mounts the TrueNAS ISO.
#
# Usage: ./provision.sh
#
# Configuration variables (customize as needed):
SERVER_NAME="truenas-repro"
VOLUME_NAME="truenas-repro-data"
SERVER_TYPE="cx23"
LOCATION="nbg1"
SSH_KEY="steve@workstation"
IMAGE="debian-12"
VOLUME_SIZE=10
TRUENAS_ISO="TrueNAS-SCALE-25.04.2.5.iso"

set -euo pipefail

echo "=== TrueNAS SCALE Hetzner Cloud Provisioning ==="
echo ""

# Check if server already exists
if hcloud server describe "$SERVER_NAME" &>/dev/null; then
    echo "✓ Server '$SERVER_NAME' already exists"
    SERVER_ID=$(hcloud server describe "$SERVER_NAME" -o json | jq -r '.id')
else
    echo "→ Creating server '$SERVER_NAME' (type: $SERVER_TYPE, location: $LOCATION)..."
    hcloud server create \
        --name "$SERVER_NAME" \
        --type "$SERVER_TYPE" \
        --image "$IMAGE" \
        --location "$LOCATION" \
        --ssh-key "$SSH_KEY" \
        --without-ipv4=false
    SERVER_ID=$(hcloud server describe "$SERVER_NAME" -o json | jq -r '.id')
    echo "✓ Server created (ID: $SERVER_ID)"
fi

# Check if volume already exists
if hcloud volume describe "$VOLUME_NAME" &>/dev/null; then
    echo "✓ Volume '$VOLUME_NAME' already exists"
    VOLUME_ID=$(hcloud volume describe "$VOLUME_NAME" -o json | jq -r '.id')
    VOLUME_SERVER=$(hcloud volume describe "$VOLUME_NAME" -o json | jq -r '.server // empty')
    
    if [ -z "$VOLUME_SERVER" ]; then
        echo "→ Attaching volume to server..."
        hcloud volume attach "$VOLUME_NAME" --server "$SERVER_NAME"
        echo "✓ Volume attached"
    else
        echo "✓ Volume already attached to server"
    fi
else
    echo "→ Creating volume '$VOLUME_NAME' (size: ${VOLUME_SIZE}GB)..."
    hcloud volume create \
        --name "$VOLUME_NAME" \
        --size "$VOLUME_SIZE" \
        --location "$LOCATION"
    VOLUME_ID=$(hcloud volume describe "$VOLUME_NAME" -o json | jq -r '.id')
    echo "✓ Volume created (ID: $VOLUME_ID)"
    
    echo "→ Attaching volume to server..."
    hcloud volume attach "$VOLUME_NAME" --server "$SERVER_NAME"
    echo "✓ Volume attached"
fi

# Check if ISO is already attached
CURRENT_ISO=$(hcloud server describe "$SERVER_NAME" -o json | jq -r '.iso.name // empty')
if [ "$CURRENT_ISO" = "$TRUENAS_ISO" ]; then
    echo "✓ TrueNAS ISO '$TRUENAS_ISO' already attached"
else
    echo "→ Attaching TrueNAS ISO '$TRUENAS_ISO'..."
    hcloud server attach-iso "$SERVER_NAME" "$TRUENAS_ISO"
    echo "✓ ISO attached"
fi

# Reboot server to boot from ISO
echo "→ Rebooting server to boot from ISO..."
hcloud server reboot "$SERVER_NAME"
echo "✓ Server rebooted"

echo ""
echo "=== Provisioning Complete ==="
echo ""

# Display server details
SERVER_INFO=$(hcloud server describe "$SERVER_NAME" -o json)
IPV4=$(echo "$SERVER_INFO" | jq -r '.public_net.ipv4.ip')
IPV6=$(echo "$SERVER_INFO" | jq -r '.public_net.ipv6.ip')
STATUS=$(echo "$SERVER_INFO" | jq -r '.status')

echo "Server Details:"
echo "  Name:     $SERVER_NAME"
echo "  Type:     $SERVER_TYPE"
echo "  Status:   $STATUS"
echo "  IPv4:     $IPV4"
echo "  IPv6:     $IPV6"
echo "  ISO:      $TRUENAS_ISO"
echo ""
echo "Volume Details:"
echo "  Name:     $VOLUME_NAME"
echo "  Size:     ${VOLUME_SIZE}GB"
echo ""
echo "Next Steps:"
echo "  1. Open Hetzner Cloud Console: https://console.hetzner.cloud"
echo "  2. Navigate to Servers → $SERVER_NAME → Console"
echo "  3. Follow the TrueNAS installation guide: docs/truenas-install.md"
echo ""
