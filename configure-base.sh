#!/bin/bash
# TrueNAS SCALE Base Configuration Script
# Sets up ZFS pool mountpoint, NFS+SMB services, SSH password auth, and repo clone
# Run from your local workstation after TrueNAS is installed
#
# Usage: bash configure-base.sh <truenas-ip>
# Example: bash configure-base.sh 91.99.101.94
set -euo pipefail

IP="${1:?Usage: $0 <truenas-ip>}"
SSH_USER="truenas_admin"
REPO_URL="https://github.com/StephanMeijer/truenas-repro.git"
POOL="repro-pool"
MOUNT="/mnt/repro-pool"

echo "==> Fixing ZFS pool mountpoint to ${MOUNT}..."
ssh "${SSH_USER}@${IP}" "sudo zfs set mountpoint=${MOUNT} ${POOL}"

echo "==> Enabling and starting NFS service..."
ssh "${SSH_USER}@${IP}" "midclt call service.update nfs '{\"enable\": true}'"
ssh "${SSH_USER}@${IP}" "midclt call service.start nfs"

echo "==> Enabling and starting SMB/CIFS service..."
ssh "${SSH_USER}@${IP}" "midclt call service.update cifs '{\"enable\": true}'"
ssh "${SSH_USER}@${IP}" "midclt call service.start cifs"

echo "==> Enabling SSH password authentication..."
ssh "${SSH_USER}@${IP}" "midclt call ssh.update '{\"passwordauth\": true}'"

echo "==> Cloning truenas-repro repo on VM..."
ssh "${SSH_USER}@${IP}" "
  if [ -d /root/truenas-repro ]; then
    sudo git -C /root/truenas-repro pull
  else
    sudo git clone ${REPO_URL} /root/truenas-repro
  fi
"

echo ""
echo "==> Verification..."
echo "ZFS pool mountpoint:"
ssh "${SSH_USER}@${IP}" "sudo zfs get mountpoint ${POOL}"

echo "Service states:"
ssh "${SSH_USER}@${IP}" "midclt call service.query '[[\"service\",\"in\",[\"nfs\",\"cifs\"]]]'" | python3 -c "import sys,json; [print(s['service'], s['state']) for s in json.load(sys.stdin)]"

echo "SSH password auth:"
ssh "${SSH_USER}@${IP}" "midclt call ssh.config" | python3 -c "import sys,json; d=json.load(sys.stdin); print('passwordauth:', d.get('passwordauth'))"

echo "Repo on VM:"
ssh "${SSH_USER}@${IP}" "sudo ls /root/truenas-repro/README.md"

echo ""
echo "==> Base configuration complete!"
