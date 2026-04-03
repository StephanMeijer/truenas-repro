# Teardown

This document describes how to tear down the TrueNAS SCALE reproduction environment on Hetzner Cloud.

## Prerequisites

- `hcloud` CLI installed and configured with context `default`
- All work with the environment is complete

## Teardown Commands

```bash
# Delete the server (this destroys all data on it)
hcloud server delete truenas-repro

# Note: No Hetzner Volume was used (CX23 doesn't support volumes)
# The data pool was a file-backed ZFS pool on the boot disk

# Check for orphaned primary IPs
hcloud primary-ip list

# If any IPs show up not attached, delete them:
# hcloud primary-ip delete <ip-name>
```

## What Gets Destroyed

- TrueNAS SCALE VM (`truenas-repro`, CX23 at 91.99.101.94)
- All ZFS pool data (`repro-pool` — 1794 test documents)
- All user accounts, groups, and ACL configuration
- All NFS exports and SMB shares

## What Persists

- GitHub repo `StephanMeijer/truenas-repro` with all scripts
- Local evidence at `~/.sisyphus/evidence/`
- Source test documents at `~/Projects/github.com/docspec/documents/`

## Re-Provisioning

To recreate the environment from scratch:

```bash
# 1. Provision a new server
bash provision.sh

# 2. Install TrueNAS SCALE via Hetzner VNC console (manual)
# See docs/truenas-install.md

# 3. Run base configuration
bash configure-base.sh <new-ip>

# 4. Create users and groups
bash setup-users.sh <new-ip>

# 5. Create datasets and shares
bash setup-shares.sh <new-ip>

# 6. Configure ACLs
bash setup-acls.sh <new-ip>

# 7. Distribute test data
bash distribute-data.sh <new-ip> ~/Projects/github.com/docspec/documents/documents

# 8. Verify
ssh truenas_admin@<new-ip> sudo bash /root/truenas-repro/tests/verify-acls.sh
ssh truenas_admin@<new-ip> sudo bash /root/truenas-repro/tests/verify-integration.sh
```
