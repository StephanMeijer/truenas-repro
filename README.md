# TrueNAS SCALE Reproduction Environment

## Purpose

This repository provides a reproducible environment for testing a file search engine's per-user ACL and permission scoping on TrueNAS SCALE. It automates the provisioning of a TrueNAS SCALE instance on Hetzner Cloud with NFS and SMB shares, multiple users and groups, NFSv4 ACLs, and a test document corpus.

## What It Contains

- **TrueNAS SCALE** on Hetzner Cloud CX23 instance
- **NFS + SMB shares** with mixed access patterns
- **5 users** across 4 groups with varying permissions
- **4 groups** (engineering, finance, management, contractors)
- **NFSv4 ACLs** for fine-grained permission control
- **1794 test documents** distributed across shares with realistic ACL scenarios

## Prerequisites

- `hcloud` CLI (Hetzner Cloud)
- SSH key configured in Hetzner Cloud
- `gh` CLI (GitHub)
- `jq` (JSON processor)
- `smbclient` (SMB client utilities)
- VNC client (for TrueNAS SCALE installation)

## Quick Start

1. **Provision infrastructure:**
   ```bash
   ./provision.sh
   ```

2. **Install TrueNAS SCALE via VNC:**
   - See `docs/truenas-install.md` for detailed instructions
   - Connect to VNC endpoint provided by provision.sh

3. **Configure base system:**
   ```bash
   ./configure-base.sh
   ```

4. **Set up users and groups:**
   ```bash
   ./setup-users.sh
   ```

5. **Create shares:**
   ```bash
   ./setup-shares.sh
   ```

6. **Configure NFSv4 ACLs:**
   ```bash
   ./setup-acls.sh
   ```

7. **Distribute test documents:**
   ```bash
   ./distribute-data.sh
   ```

8. **Verify ACL enforcement:**
   ```bash
   ./tests/verify-acls.sh
   ```

## Users

| Username | Password | Groups | Purpose |
|----------|----------|--------|---------|
| alice | alice123 | engineering | Engineer with standard access |
| bob | bob123 | engineering | Engineer with standard access |
| carol | carol123 | finance | Finance team member |
| dave | dave123 | engineering, finance, management | Cross-functional access |
| eve | eve123 | contractors | External contractor (limited access) |

## Shares

| Share | Access | Purpose |
|-------|--------|---------|
| public | Everyone (ro) | Public documents |
| engineering | engineering group (rw) | Engineering team workspace |
| finance | finance group (rw) | Finance team workspace |
| shared-projects | engineering (rw), finance (ro) | Cross-team collaboration |
| management | management group (rw) | Management-only documents |
| private/{user} | Owner only (rw) | Personal user directories |

## Documentation

- `docs/truenas-install.md` — TrueNAS SCALE installation guide
- `docs/acl-design.md` — ACL architecture and permission model
- `docs/test-scenarios.md` — Test case documentation

## Testing

Run the verification suite:
```bash
./tests/verify-acls.sh
```

This validates:
- User authentication
- Share accessibility
- ACL enforcement
- Document visibility per user
