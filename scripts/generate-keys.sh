#!/usr/bin/env bash
# Generates the SSH keys the lab needs.
#
# The keys are never committed: keys/ is in .gitignore. An earlier version of
# this project had twelve private keys in version control, which is what this
# script exists to prevent.
#
# After running it, paste the .pub contents into
# src/ansible/users/group_vars/all.yml.
#
# @author Ismael Sallami Moreno

set -euo pipefail

KEY_DIR="${1:-keys}"
USERS=(admin juan maria)

mkdir -p "$KEY_DIR"

for user in "${USERS[@]}"; do
    key="$KEY_DIR/id_$user"
    if [[ -f "$key" ]]; then
        echo "skip: $key already exists"
        continue
    fi
    ssh-keygen -t ed25519 -N '' -C "$user@lab" -f "$key"
done

echo
echo "Public keys, to paste into src/ansible/users/group_vars/all.yml:"
for user in "${USERS[@]}"; do
    printf '  %-6s %s\n' "$user" "$(cat "$KEY_DIR/id_$user.pub")"
done
