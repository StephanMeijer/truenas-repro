#!/bin/bash
# Full Integration Verification for TrueNAS Repro Environment
# Run AFTER all setup (T1-T8) is complete — everything should PASS
set -uo pipefail

PASS=0; FAIL=0; TOTAL=0

check() {
  local desc="$1"; local cmd="$2"; TOTAL=$((TOTAL+1))
  if eval "$cmd" >/dev/null 2>&1; then echo "PASS: $desc"; PASS=$((PASS+1))
  else echo "FAIL: $desc"; FAIL=$((FAIL+1)); fi
}

check_count() {
  local desc="$1"; local actual="$2"; local expected="$3"; TOTAL=$((TOTAL+1))
  if [ "$actual" -eq "$expected" ]; then echo "PASS: $desc (count=$actual)"; PASS=$((PASS+1))
  else echo "FAIL: $desc (expected=$expected, actual=$actual)"; FAIL=$((FAIL+1)); fi
}

check_approx() {
  local desc="$1"; local actual="$2"; local min="$3"; local max="$4"; TOTAL=$((TOTAL+1))
  if [ "$actual" -ge "$min" ] && [ "$actual" -le "$max" ]; then
    echo "PASS: $desc (count=$actual, expected $min-$max)"; PASS=$((PASS+1))
  else echo "FAIL: $desc (count=$actual, expected $min-$max)"; FAIL=$((FAIL+1)); fi
}

echo "=== Integration Verification Suite ==="
echo "Running as: $(whoami)"
echo ""

# ============================================================
# SECTION 1: ACL verification (re-run)
# ============================================================
echo "--- Section 1: ACL verification ---"
ACL_RESULT=$(bash /root/truenas-repro/tests/verify-acls.sh 2>/dev/null | grep 'TOTAL:')
ACL_PASS=$(echo "$ACL_RESULT" | grep -oP 'PASS: \K\d+')
ACL_FAIL=$(echo "$ACL_RESULT" | grep -oP 'FAIL: \K\d+')
check_count "ACL test suite: total=42" "$((ACL_PASS + ACL_FAIL))" 42
check_count "ACL test suite: all 42 pass" "$ACL_PASS" 42
check_count "ACL test suite: zero failures" "$ACL_FAIL" 0

# ============================================================
# SECTION 2: File count verification
# ============================================================
echo "--- Section 2: File counts ---"
TOTAL_FILES=$(sudo find /mnt/repro-pool -type f | wc -l)
check_count "Total files = 1794" "$TOTAL_FILES" 1794
check_count "public: 272 files" "$(sudo find /mnt/repro-pool/public -type f | wc -l)" 272
check_count "engineering: 772 files" "$(sudo find /mnt/repro-pool/engineering -type f | wc -l)" 772
check_count "finance: 112 files" "$(sudo find /mnt/repro-pool/finance -type f | wc -l)" 112
check_count "shared-projects: 144 files" "$(sudo find /mnt/repro-pool/shared-projects -type f | wc -l)" 144
check_count "management: 393 files" "$(sudo find /mnt/repro-pool/management -type f | wc -l)" 393
PRIVATE_FILES=$(sudo find /mnt/repro-pool/private -type f | wc -l)
check_count "private: 101 files total" "$PRIVATE_FILES" 101

# ============================================================
# SECTION 3: Per-user visible file counts
# ============================================================
echo "--- Section 3: Per-user file visibility ---"
# alice: public(272) + engineering(772) + shared-projects(144) + private/alice(26) ≈ 1214
ALICE_FILES=$(sudo -u alice bash -c 'find /mnt/repro-pool -type f 2>/dev/null | wc -l')
check_approx "alice sees ~1214 files" "$ALICE_FILES" 1200 1230

# carol: public(272) + finance(112) + shared-projects(144 read-only) + private/carol(25) ≈ 553
CAROL_FILES=$(sudo -u carol bash -c 'find /mnt/repro-pool -type f 2>/dev/null | wc -l')
check_approx "carol sees ~553 files" "$CAROL_FILES" 540 570

# dave: public(272) + engineering(772) + finance(112) + shared-projects(144) + management(393) + private/dave(25) ≈ 1718
DAVE_FILES=$(sudo -u dave bash -c 'find /mnt/repro-pool -type f 2>/dev/null | wc -l')
check_approx "dave sees ~1718 files" "$DAVE_FILES" 1680 1740

# eve: public(272) only
EVE_FILES=$(sudo -u eve bash -c 'find /mnt/repro-pool -type f 2>/dev/null | wc -l')
check_approx "eve sees ~272 files (public only)" "$EVE_FILES" 265 280

# ============================================================
# SECTION 4: Cross-protocol integration
# ============================================================
echo "--- Section 4: Cross-protocol (SMB write -> filesystem read) ---"
echo "cross-proto-integration-test" | sudo tee /tmp/cp-test.txt >/dev/null
check "alice can upload to engineering via SMB" \
  "smbclient //localhost/engineering -U alice%alice123 -c 'put /tmp/cp-test.txt cp-integration-test.txt' 2>/dev/null"
check "bob can read SMB-uploaded file via filesystem" \
  "sudo -u bob bash -c 'cat /mnt/repro-pool/engineering/cp-integration-test.txt'"
check "carol is denied filesystem read of engineering file" \
  "! sudo -u carol bash -c 'cat /mnt/repro-pool/engineering/cp-integration-test.txt 2>/dev/null'"
# Cleanup
smbclient //localhost/engineering -U alice%alice123 -c 'del cp-integration-test.txt' >/dev/null 2>&1 || true
sudo rm -f /tmp/cp-test.txt

# ============================================================
# SECTION 5: NFS availability
# ============================================================
echo "--- Section 5: NFS exports ---"
NFS_EXPORTS=$(showmount -e localhost 2>/dev/null | grep -c '/mnt/repro-pool/' || true)
check_approx "6 NFS exports visible" "$NFS_EXPORTS" 6 6

echo ""
echo "=============================="
echo "TOTAL: $TOTAL | PASS: $PASS | FAIL: $FAIL"
echo "=============================="
