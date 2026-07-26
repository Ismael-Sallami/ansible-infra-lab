#!/usr/bin/env bash
# Generates the SSH keys the lab needs.
#
# The names and the folder are the ones the playbooks expect:
# src/ansible/users/group_vars/all.yml reads claves/id_rsa_<user>.pub through
# a lookup, and the webserver inventory points at claves/id_rsa_admin.
#
# The keys are never committed: claves/ is in .gitignore. An earlier version of
# this project had twelve private keys in version control, which is what this
# script exists to prevent.
#
# @author Ismael Sallami Moreno

set -euo pipefail

KEY_DIR="${1:-claves}"
USERS=(admin juan maria)

mkdir -p "$KEY_DIR"

for user in "${USERS[@]}"; do
    key="$KEY_DIR/id_rsa_$user"
    if [[ -f "$key" ]]; then
        echo "skip: $key already exists"
        continue
    fi
    ssh-keygen -t ed25519 -N '' -C "$user@lab" -f "$key"
done

echo
echo "Keys in $KEY_DIR/. The playbooks read the .pub files from there, so there"
echo "is nothing to paste anywhere."
