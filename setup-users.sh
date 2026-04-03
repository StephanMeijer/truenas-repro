#!/usr/bin/env bash
set -euo pipefail

# setup-users.sh - Create users, groups, and group memberships on TrueNAS SCALE
# Usage: bash setup-users.sh <truenas_ip>

if [ $# -ne 1 ]; then
    echo "Usage: $0 <truenas_ip>"
    exit 1
fi

TRUENAS_IP="$1"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_ed25519}"
SSH_USER="truenas_admin"

# Helper function to run midclt commands
run_midclt() {
    ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_USER@$TRUENAS_IP" "$@"
}

echo "=== Creating groups ==="

# Create groups if they don't exist
for group in engineering finance management contractors; do
    if ! run_midclt "midclt call group.query '[[\"group\",\"=\",\"$group\"]]'" | grep -q "$group"; then
        echo "Creating group: $group"
        run_midclt "midclt call group.create '{\"name\": \"$group\", \"smb\": false}'"
    else
        echo "Group already exists: $group"
    fi
done

echo ""
echo "=== Getting group IDs ==="

# Get group IDs
GROUP_JSON=$(run_midclt "midclt call group.query '[[\"group\",\"in\",[\"engineering\",\"finance\",\"management\",\"contractors\"]]]'")
GROUP_IDS=$(echo "$GROUP_JSON" | python3 -c '
import sys, json
groups = json.load(sys.stdin)
for g in groups:
    print(f"{g[\"group\"]}={g[\"id\"]}")
')

# Parse group IDs into variables
declare -A GROUP_MAP
while IFS='=' read -r name id; do
    GROUP_MAP["$name"]="$id"
done <<< "$GROUP_IDS"

ENG_ID="${GROUP_MAP[engineering]}"
FIN_ID="${GROUP_MAP[finance]}"
MGT_ID="${GROUP_MAP[management]}"
CON_ID="${GROUP_MAP[contractors]}"

echo "engineering: $ENG_ID"
echo "finance: $FIN_ID"
echo "management: $MGT_ID"
echo "contractors: $CON_ID"

echo ""
echo "=== Creating users ==="

# Define users: username, password, groups (space-separated)
declare -a USERS=(
    "alice:alice123:$ENG_ID"
    "bob:bob123:$ENG_ID"
    "carol:carol123:$FIN_ID"
    "dave:dave123:$ENG_ID $FIN_ID $MGT_ID"
    "eve:eve123:$CON_ID"
)

for user_spec in "${USERS[@]}"; do
    IFS=':' read -r username password groups <<< "$user_spec"
    
    # Check if user exists
    if run_midclt "midclt call user.query '[[\"username\",\"=\",\"$username\"]]'" | grep -q "$username"; then
        echo "User already exists: $username"
    else
        echo "Creating user: $username"
        
        # Convert space-separated group IDs to JSON array
        groups_json="[$(echo "$groups" | tr ' ' ',' )]"
        
        run_midclt "midclt call user.create '{\"username\": \"$username\", \"full_name\": \"${username^}\", \"password\": \"$password\", \"shell\": \"/usr/bin/bash\", \"group_create\": true, \"groups\": $groups_json}'" > /dev/null
    fi
done

echo ""
echo "=== Enabling SSH password login ==="

# Get user IDs and enable SSH password login
USER_JSON=$(run_midclt "midclt call user.query '[[\"username\",\"in\",[\"alice\",\"bob\",\"carol\",\"dave\",\"eve\"]]]'")
USER_IDS=$(echo "$USER_JSON" | python3 -c '
import sys, json
users = json.load(sys.stdin)
for u in users:
    print(f"{u[\"username\"]}={u[\"id\"]}")
')

while IFS='=' read -r username user_id; do
    # Check if SSH password is already enabled
    if run_midclt "midclt call user.query '[[\"username\",\"=\",\"$username\"]]'" | grep -q '"ssh_password_enabled": true'; then
        echo "SSH password already enabled: $username"
    else
        echo "Enabling SSH password login: $username"
        run_midclt "midclt call user.update $user_id '{\"ssh_password_enabled\": true}'" > /dev/null
    fi
done <<< "$USER_IDS"

echo ""
echo "=== Verification ==="
echo "Users created:"
USERS_JSON=$(run_midclt "midclt call user.query '[[\"username\",\"in\",[\"alice\",\"bob\",\"carol\",\"dave\",\"eve\"]]]'")
echo "$USERS_JSON" | python3 -c '
import sys, json
users = json.load(sys.stdin)
for u in sorted(users, key=lambda x: x["username"]):
    print(f"  {u[\"username\"]:10} uid={u[\"uid\"]:5} ssh_password_enabled={u[\"ssh_password_enabled\"]}")
'

echo ""
echo "Groups created:"
GROUPS_JSON=$(run_midclt "midclt call group.query '[[\"group\",\"in\",[\"engineering\",\"finance\",\"management\",\"contractors\"]]]'")
echo "$GROUPS_JSON" | python3 -c '
import sys, json
groups = json.load(sys.stdin)
for g in sorted(groups, key=lambda x: x["group"]):
    print(f"  {g[\"group\"]:15} id={g[\"id\"]:3} gid={g[\"gid\"]:5}")
'

echo ""
echo "Setup complete!"
