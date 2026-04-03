#!/bin/bash
# ACL Verification Test Suite for TrueNAS Repro Environment
# TDD: Run BEFORE ACL configuration — positive access tests FAIL
# Run AFTER ACL configuration (T7) — all tests should PASS
#
# Usage: bash tests/verify-acls.sh
# Must be run as truenas_admin (with sudo) on the TrueNAS VM
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0

check() {
  local desc="$1"
  local cmd="$2"
  TOTAL=$((TOTAL+1))
  if eval "$cmd" >/dev/null 2>&1; then
    echo "PASS: $desc"
    PASS=$((PASS+1))
  else
    echo "FAIL: $desc"
    FAIL=$((FAIL+1))
  fi
}

check_deny() {
  local desc="$1"
  local cmd="$2"
  TOTAL=$((TOTAL+1))
  if eval "$cmd" >/dev/null 2>&1; then
    echo "FAIL: $desc (should be denied but was allowed)"
    FAIL=$((FAIL+1))
  else
    echo "PASS: $desc (correctly denied)"
    PASS=$((PASS+1))
  fi
}

BASE=/mnt/repro-pool

echo "=== ACL Verification Test Suite ==="
echo "Running as: $(whoami)"
echo ""

# ============================================================
# SECTION 1: alice (engineering) — positive access
# ============================================================
echo "--- alice: positive access ---"
check "alice can list public" "sudo -u alice bash -c 'ls $BASE/public'"
check "alice can write to public" "sudo -u alice bash -c 'touch $BASE/public/.alice-test && rm $BASE/public/.alice-test'"
check "alice can list engineering" "sudo -u alice bash -c 'ls $BASE/engineering'"
check "alice can write to engineering" "sudo -u alice bash -c 'touch $BASE/engineering/.alice-test && rm $BASE/engineering/.alice-test'"
check "alice can list shared-projects" "sudo -u alice bash -c 'ls $BASE/shared-projects'"
check "alice can write to shared-projects" "sudo -u alice bash -c 'touch $BASE/shared-projects/.alice-test && rm $BASE/shared-projects/.alice-test'"
check "alice can list private/alice" "sudo -u alice bash -c 'ls $BASE/private/alice'"
check "alice can write to private/alice" "sudo -u alice bash -c 'touch $BASE/private/alice/.alice-test && rm $BASE/private/alice/.alice-test'"

# ============================================================
# SECTION 2: alice — negative access (denials)
# ============================================================
echo "--- alice: negative access (should be denied) ---"
check_deny "alice cannot write to finance" "sudo -u alice bash -c 'touch $BASE/finance/.alice-test'"
check_deny "alice cannot write to management" "sudo -u alice bash -c 'touch $BASE/management/.alice-test'"
check_deny "alice cannot list private/bob" "sudo -u alice bash -c 'ls $BASE/private/bob'"
check_deny "alice cannot write to private/carol" "sudo -u alice bash -c 'touch $BASE/private/carol/.alice-test'"

# ============================================================
# SECTION 3: bob (engineering) — positive access
# ============================================================
echo "--- bob: positive access ---"
check "bob can list engineering" "sudo -u bob bash -c 'ls $BASE/engineering'"
check "bob can write to engineering" "sudo -u bob bash -c 'touch $BASE/engineering/.bob-test && rm $BASE/engineering/.bob-test'"
check "bob can list shared-projects" "sudo -u bob bash -c 'ls $BASE/shared-projects'"
check "bob can write to private/bob" "sudo -u bob bash -c 'touch $BASE/private/bob/.bob-test && rm $BASE/private/bob/.bob-test'"

# ============================================================
# SECTION 4: carol (finance) — positive and negative
# ============================================================
echo "--- carol: access checks ---"
check "carol can list public" "sudo -u carol bash -c 'ls $BASE/public'"
check "carol can list finance" "sudo -u carol bash -c 'ls $BASE/finance'"
check "carol can write to finance" "sudo -u carol bash -c 'touch $BASE/finance/.carol-test && rm $BASE/finance/.carol-test'"
check "carol can list shared-projects (read-only)" "sudo -u carol bash -c 'ls $BASE/shared-projects'"
check "carol can write to private/carol" "sudo -u carol bash -c 'touch $BASE/private/carol/.carol-test && rm $BASE/private/carol/.carol-test'"
check_deny "carol cannot write to engineering" "sudo -u carol bash -c 'touch $BASE/engineering/.carol-test'"
check_deny "carol cannot write to shared-projects" "sudo -u carol bash -c 'touch $BASE/shared-projects/.carol-test'"
check_deny "carol cannot list private/alice" "sudo -u carol bash -c 'ls $BASE/private/alice'"

# ============================================================
# SECTION 5: dave (engineering+finance+management) — broad access
# ============================================================
echo "--- dave: broad access ---"
check "dave can write to engineering" "sudo -u dave bash -c 'touch $BASE/engineering/.dave-test && rm $BASE/engineering/.dave-test'"
check "dave can write to finance" "sudo -u dave bash -c 'touch $BASE/finance/.dave-test && rm $BASE/finance/.dave-test'"
check "dave can write to management" "sudo -u dave bash -c 'touch $BASE/management/.dave-test && rm $BASE/management/.dave-test'"
check "dave can write to shared-projects" "sudo -u dave bash -c 'touch $BASE/shared-projects/.dave-test && rm $BASE/shared-projects/.dave-test'"
check "dave can write to private/dave" "sudo -u dave bash -c 'touch $BASE/private/dave/.dave-test && rm $BASE/private/dave/.dave-test'"
check_deny "dave cannot list private/alice" "sudo -u dave bash -c 'ls $BASE/private/alice'"

# ============================================================
# SECTION 6: eve (contractors) — minimal access
# ============================================================
echo "--- eve: minimal access ---"
check "eve can list public" "sudo -u eve bash -c 'ls $BASE/public'"
check_deny "eve cannot write to engineering" "sudo -u eve bash -c 'touch $BASE/engineering/.eve-test'"
check_deny "eve cannot list finance" "sudo -u eve bash -c 'ls $BASE/finance'"
check_deny "eve cannot list management" "sudo -u eve bash -c 'ls $BASE/management'"
check_deny "eve cannot list shared-projects" "sudo -u eve bash -c 'ls $BASE/shared-projects'"
check_deny "eve cannot list private/alice" "sudo -u eve bash -c 'ls $BASE/private/alice'"

# ============================================================
# SECTION 7: ACL inheritance test (management subdir)
# ============================================================
echo "--- inheritance: management subdir ---"
sudo -u root bash -c "mkdir -p $BASE/management/strategy/inherit-test 2>/dev/null" || sudo mkdir -p $BASE/management/strategy/inherit-test 2>/dev/null || true
check "dave can access management/strategy subdir" "sudo -u dave bash -c 'ls $BASE/management/strategy'"
check "dave can write to management/strategy subdir" "sudo -u dave bash -c 'touch $BASE/management/strategy/.dave-inherit && rm $BASE/management/strategy/.dave-inherit'"
check_deny "eve cannot access management/strategy subdir (inherited deny)" "sudo -u eve bash -c 'ls $BASE/management/strategy'"

# ============================================================
# SECTION 8: Cross-protocol test (SMB write, filesystem read)
# ============================================================
echo "--- cross-protocol: SMB write -> filesystem read ---"
# Write via SMB as alice
echo "cross-protocol-test-content" | sudo tee /tmp/smb-test-file.txt >/dev/null
check "alice can write to engineering via SMB" "smbclient //localhost/engineering -U alice%alice123 -c 'put /tmp/smb-test-file.txt cross-protocol-test.txt' 2>/dev/null"
check "bob can read SMB-created file via filesystem" "sudo -u bob bash -c 'cat $BASE/engineering/cross-protocol-test.txt'"
check_deny "carol cannot read SMB-created file in engineering via filesystem" "sudo -u carol bash -c 'cat $BASE/engineering/cross-protocol-test.txt'"
# Cleanup
smbclient //localhost/engineering -U alice%alice123 -c 'del cross-protocol-test.txt' >/dev/null 2>&1 || true
rm -f /tmp/smb-test-file.txt

echo ""
echo "=============================="
echo "TOTAL: $TOTAL | PASS: $PASS | FAIL: $FAIL"
echo "=============================="
if [ "$FAIL" -gt 0 ]; then
  echo "NOTE: FAIL is expected before ACL configuration (TDD)"
fi
