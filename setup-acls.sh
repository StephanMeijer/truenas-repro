#!/bin/bash
# setup-acls.sh — Configure access controls on TrueNAS datasets
# Usage: sudo bash setup-acls.sh
# Must be run as root on the TrueNAS VM
# Can be re-run safely (all operations are idempotent)
set -euo pipefail

BASE=/mnt/repro-pool
POOL=repro-pool

echo "=== TrueNAS ACL Configuration ==="

# ============================================================
# Step 1: Set ZFS ACL type to POSIX on all datasets
# ============================================================
echo "--- Setting ZFS acltype=posixacl, aclinherit=passthrough ---"
for ds in \
  $POOL \
  $POOL/public \
  $POOL/engineering \
  $POOL/finance \
  $POOL/shared-projects \
  $POOL/management \
  $POOL/private \
  $POOL/private/alice \
  $POOL/private/bob \
  $POOL/private/carol \
  $POOL/private/dave; do
  zfs set acltype=posixacl aclinherit=passthrough "$ds"
  echo "  $ds: OK"
done

# ============================================================
# Step 2: Set ownership and base permissions
# ============================================================
echo "--- Setting ownership and permissions ---"

# Public: root-owned, world-accessible (rwx for all)
chown root:root $BASE/public
chmod 777 $BASE/public
echo "  public: root:root 777"

# Engineering: root:engineering, setgid, group rwx, others none
chown root:engineering $BASE/engineering
chmod 2770 $BASE/engineering
for subdir in design-docs source-code; do
  chown root:engineering "$BASE/engineering/$subdir"
  chmod 2770 "$BASE/engineering/$subdir"
done
echo "  engineering: root:engineering 2770 (+ subdirs)"

# Finance: root:finance, setgid, group rwx, others none
chown root:finance $BASE/finance
chmod 2770 $BASE/finance
for subdir in reports budgets; do
  chown root:finance "$BASE/finance/$subdir"
  chmod 2770 "$BASE/finance/$subdir"
done
echo "  finance: root:finance 2770 (+ subdirs)"

# Shared-projects: root:engineering, setgid (finance gets r-x via ACL)
chown root:engineering $BASE/shared-projects
chmod 2770 $BASE/shared-projects
[ -d "$BASE/shared-projects/project-alpha" ] && chown root:engineering "$BASE/shared-projects/project-alpha" && chmod 2770 "$BASE/shared-projects/project-alpha"
echo "  shared-projects: root:engineering 2770"

# Management: root:management, setgid (contractors denied via ACL)
chown root:management $BASE/management
chmod 2770 $BASE/management
for subdir in strategy hr; do
  chown root:management "$BASE/management/$subdir"
  chmod 2770 "$BASE/management/$subdir"
done
mkdir -p "$BASE/management/strategy/inherit-test"
chown root:management "$BASE/management/strategy/inherit-test"
chmod 2770 "$BASE/management/strategy/inherit-test"
echo "  management: root:management 2770 (+ subdirs)"

# Private: container with execute-only for traversal
chmod 711 $BASE/private
echo "  private: 711 (traverse only)"

# Private user dirs: owner-only
for user in alice bob carol dave; do
  chown "$user:$user" "$BASE/private/$user"
  chmod 700 "$BASE/private/$user"
  echo "  private/$user: $user:$user 700"
done

# ============================================================
# Step 3: Apply POSIX ACLs
# ============================================================
echo "--- Applying POSIX ACLs ---"

# Shared-projects: finance group gets read-only (r-x) access
setfacl -m 'g:finance:r-x' $BASE/shared-projects
setfacl -d -m 'g:engineering:rwx,g:finance:r-x' $BASE/shared-projects
[ -d "$BASE/shared-projects/project-alpha" ] && setfacl -m 'g:finance:r-x' "$BASE/shared-projects/project-alpha"
echo "  shared-projects: +finance:r-x"

# Engineering: default ACLs for inheritance
setfacl -d -m 'g:engineering:rwx' $BASE/engineering
for subdir in design-docs source-code; do
  setfacl -m 'g:engineering:rwx' "$BASE/engineering/$subdir"
  setfacl -d -m 'g:engineering:rwx' "$BASE/engineering/$subdir"
done
echo "  engineering: defaults set"

# Finance: default ACLs for inheritance
setfacl -d -m 'g:finance:rwx' $BASE/finance
for subdir in reports budgets; do
  setfacl -m 'g:finance:rwx' "$BASE/finance/$subdir"
  setfacl -d -m 'g:finance:rwx' "$BASE/finance/$subdir"
done
echo "  finance: defaults set"

# Management: explicit deny for contractors group, recursive
setfacl -R -m 'g:contractors:---' $BASE/management
setfacl -R -d -m 'g:management:rwx,g:contractors:---' $BASE/management
echo "  management: +contractors:--- (recursive)"

echo ""
echo "=== ACL Configuration Complete ==="
echo "Run 'bash tests/verify-acls.sh' to verify all 42 tests pass."
