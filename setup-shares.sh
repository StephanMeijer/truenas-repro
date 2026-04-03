#!/bin/bash
# setup-shares.sh - Create ZFS datasets and configure NFS/SMB shares on TrueNAS SCALE
# Usage: ./setup-shares.sh <truenas_ip>

set -e

TRUENAS_IP="${1:-91.99.101.94}"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
SSH_USER="truenas_admin"
SSH_OPTS="-i $SSH_KEY -o StrictHostKeyChecking=no"

SSH="ssh $SSH_OPTS $SSH_USER@$TRUENAS_IP"

echo "=== TrueNAS Share Setup Script ==="
echo "Target: $TRUENAS_IP"
echo ""

# Step 1: Create top-level datasets
echo "Step 1: Creating top-level datasets..."
for ds in public engineering finance shared-projects management private; do
  if $SSH "midclt call pool.dataset.query | python3 -c 'import sys,json; print(any(d[\"name\"] == \"repro-pool/$ds\" for d in json.load(sys.stdin)))'" 2>/dev/null | grep -q True; then
    echo "  ✓ repro-pool/$ds already exists"
  else
    echo "  Creating repro-pool/$ds..."
    $SSH "midclt call pool.dataset.create '{\"name\": \"repro-pool/$ds\", \"aclmode\": \"PASSTHROUGH\"}'" > /dev/null 2>&1
  fi
done

# Step 2: Create per-user private datasets
echo "Step 2: Creating private user datasets..."
for user in alice bob carol dave; do
  if $SSH "midclt call pool.dataset.query | python3 -c 'import sys,json; print(any(d[\"name\"] == \"repro-pool/private/$user\" for d in json.load(sys.stdin)))'" 2>/dev/null | grep -q True; then
    echo "  ✓ repro-pool/private/$user already exists"
  else
    echo "  Creating repro-pool/private/$user..."
    $SSH "midclt call pool.dataset.create '{\"name\": \"repro-pool/private/$user\", \"aclmode\": \"PASSTHROUGH\"}'" > /dev/null 2>&1
  fi
done

# Step 3: Create subdirectories
echo "Step 3: Creating subdirectories..."
$SSH "
  sudo mkdir -p /mnt/repro-pool/engineering/design-docs /mnt/repro-pool/engineering/source-code
  sudo mkdir -p /mnt/repro-pool/finance/reports /mnt/repro-pool/finance/budgets
  sudo mkdir -p /mnt/repro-pool/shared-projects/project-alpha
  sudo mkdir -p /mnt/repro-pool/management/strategy /mnt/repro-pool/management/hr
" > /dev/null 2>&1
echo "  ✓ Subdirectories created"

# Step 4: Configure NFS exports
echo "Step 4: Configuring NFS exports..."
$SSH << 'EOSSH'
for ds in public engineering finance shared-projects management private; do
  sudo exportfs -o rw,no_subtree_check,no_root_squash "*:/mnt/repro-pool/$ds" 2>/dev/null
done
EOSSH
echo "  ✓ NFS exports configured"

# Step 5: Configure SMB shares
echo "Step 5: Configuring SMB shares..."
for ds in public engineering finance shared-projects management private; do
  smb_name=$(echo "$ds" | sed 's/-/_/g')
  if $SSH "sudo net conf listshares | grep -q $smb_name" 2>/dev/null; then
    echo "  ✓ SMB share $smb_name already exists"
  else
    echo "  Creating SMB share $smb_name..."
    $SSH "sudo net conf addshare $smb_name /mnt/repro-pool/$ds writeable=y guest_ok=y" > /dev/null 2>&1
  fi
done

# Step 6: Restart services
echo "Step 6: Restarting services..."
$SSH "midclt call service.restart nfs" > /dev/null 2>&1
$SSH "midclt call service.restart cifs" > /dev/null 2>&1
echo "  ✓ Services restarted"

# Step 7: Verify
echo "Step 7: Verifying configuration..."
echo ""
echo "Datasets:"
$SSH "sudo zfs list -r repro-pool" | head -12
echo ""
echo "NFS Exports:"
$SSH "sudo exportfs -v | grep repro-pool" | wc -l | xargs echo "  Exports configured:"
echo ""
echo "SMB Shares:"
$SSH "sudo net conf listshares | grep -E '(public|engineering|finance|shared|management|private)'" | wc -l | xargs echo "  Shares configured:"

echo ""
echo "=== Setup Complete ==="
