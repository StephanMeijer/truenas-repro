# TrueNAS SCALE Installation via VNC Console

## Prerequisites

- Server `truenas-repro` provisioned with `provision.sh`
- TrueNAS ISO mounted and server rebooted
- Access to Hetzner Cloud Console

## Installation Steps

### 1. Access the Console

1. Open Hetzner Cloud Console: https://console.hetzner.cloud
2. Navigate to: **Servers** → **truenas-repro** → **Console** (button in top-right)
3. Wait for the TrueNAS installer to boot (~1-2 minutes)
4. You should see the TrueNAS installer menu with numbered options

### 2. Start Installation

1. Select **"1. Install/Upgrade"** from the menu
2. The installer will scan for available disks
3. Select the **40GB disk** (typically `/dev/sda` — this is the boot disk, NOT the 10GB volume)
4. Confirm the selection with **"Yes"** when prompted

### 3. Configure Installation

1. **Set root password**: Enter a memorable password (you'll need this for SSH and Web UI access)
2. **Confirm password**: Re-enter the password
3. **Swap partition**: Accept the default swap size when prompted
4. **Installation**: The installer will format the disk and install TrueNAS SCALE

### 4. Complete Installation

1. When installation completes, select **"Reboot System"**
2. The server will reboot and boot into TrueNAS SCALE
3. After reboot, you'll see the TrueNAS console menu with system information
4. **Note the IPv4 address** displayed on the console (you'll need this for SSH/Web UI)

## Enable SSH Access

After the system boots into TrueNAS, you need to enable SSH to access the system remotely.

### Option A: Via Console Shell (Recommended)

1. From the TrueNAS console menu, select **"6. Shell"** or similar shell option
2. Run the following commands:

```bash
# Enable SSH service
midclt call service.update "ssh" '{"enable": true}'

# Start SSH service
midclt call service.start "ssh"

# Verify SSH is running
midclt call service.query | jq '.[] | select(.service == "ssh")'
```

3. Exit the shell (type `exit` or `logout`)

### Option B: Via Web UI

1. Open `http://<server-ipv4>` in your browser (replace with actual IPv4 from console)
2. Login with:
   - Username: `root`
   - Password: (the password you set during installation)
3. Navigate to: **System Settings** → **Services** → **SSH**
4. Enable SSH and click **Start**

## Verify SSH Access

From your workstation, verify SSH connectivity:

```bash
# Replace with actual server IPv4 address
ssh root@91.99.101.94

# Once logged in, verify TrueNAS version
midclt call system.info | jq '.version'
# Expected output: "TrueNAS-SCALE-25.04.2.5" or similar
```

## Detach ISO

Once you've confirmed SSH works and the system is stable, detach the ISO:

```bash
hcloud server detach-iso truenas-repro
```

This frees up the ISO for other servers and prevents accidental boots from the installer.

## Attach Data Volume

The 10GB volume (`truenas-repro-data`) is attached to the server but not yet formatted. TrueNAS will format it as ZFS when you create a storage pool.

### Create ZFS Pool

1. Access the TrueNAS Web UI: `http://<server-ipv4>`
2. Navigate to: **Storage** → **Pools** → **Create Pool**
3. Select the 10GB volume (typically `/dev/sdb`)
4. Configure pool settings:
   - **Pool name**: `data` (or your preferred name)
   - **Encryption**: Optional (recommended for security)
   - **Confirm**: Review and create the pool
5. TrueNAS will format the volume as ZFS and create the pool

## Troubleshooting

### Can't access Web UI

- Verify the server is running: `hcloud server describe truenas-repro`
- Check the IPv4 address from the console
- Ensure SSH is enabled (see "Enable SSH Access" section)
- Try accessing via IPv6 if IPv4 fails: `http://[2a01:4f8:1c18:8aee::1]`

### SSH connection refused

- Verify SSH is enabled on the TrueNAS console
- Check firewall rules (Hetzner Cloud allows all traffic by default)
- Ensure you're using the correct IPv4 address from the console

### Volume not visible in TrueNAS

- The volume may take a few moments to appear after boot
- Refresh the Storage page in the Web UI
- If still not visible, check volume attachment: `hcloud volume describe truenas-repro-data`

## Next Steps

After successful installation and SSH access:

1. Configure storage pools and datasets
2. Set up SMB/NFS shares for media or backups
3. Configure services (Docker, VMs, etc.)
4. Set up automated snapshots and replication
5. Configure email alerts and monitoring

For more information, see the [TrueNAS SCALE Documentation](https://www.truenas.com/docs/scale/).
