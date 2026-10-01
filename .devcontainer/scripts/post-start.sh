#!/usr/bin/env bash
set -e

SSH_KEY="/home/frappe/.ssh/id_ed25519"
SSH_ENV="/home/frappe/.ssh-agent.env"
BASHRC="/home/frappe/.bashrc"

if [ -f "$SSH_KEY" ] && ! ssh-keygen -y -P "" -f "$SSH_KEY" >/dev/null 2>&1; then
    echo "Found passphrase-protected SSH key at $SSH_KEY. Initializing ssh-agent..."
    (
        ssh-agent -s > "$SSH_ENV"
        eval "$(cat "$SSH_ENV")"
        if ! grep -qF "source $SSH_ENV" "$BASHRC" 2>/dev/null; then
            echo "source $SSH_ENV" >> "$BASHRC"
        fi
        ssh-add "$SSH_KEY" < /dev/tty 2>/dev/null || echo "SSH key is passphrase-protected: run 'ssh-add ~/.ssh/id_ed25519' in your terminal to unlock it."
    ) || true
else
    echo "SSH key not found or not passphrase-protected - skipping ssh-agent setup."
fi
