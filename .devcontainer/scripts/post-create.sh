#!/usr/bin/env bash
set -e

echo "==> Running Dev Container postCreate setup..."

# 1. Verify / ensure pre-commit is available
if ! command -v pre-commit >/dev/null 2>&1; then
    echo "pre-commit not found in PATH, installing via uv tool..."
    uv tool install pre-commit
else
    echo "pre-commit is installed: $(pre-commit --version)"
fi

# 2. Check Git platform CLI tools (glab & gh)
if command -v glab >/dev/null 2>&1; then
    echo "GitLab CLI is available: $(glab --version | head -n 1)"
fi
if command -v gh >/dev/null 2>&1; then
    echo "GitHub CLI is available: $(gh --version | head -n 1)"
fi

# 3. Configure SSH commit signing and allowed_signers if the key is mounted
SSH_KEY_PUB="/home/frappe/.ssh/id_ed25519.pub"
ALLOWED_SIGNERS="/home/frappe/.ssh/allowed_signers"

if [ -f "$SSH_KEY_PUB" ]; then
    echo "Found SSH public key at $SSH_KEY_PUB, configuring Git commit signing..."
    git config --global user.signingkey "$SSH_KEY_PUB"
    git config --global gpg.format ssh
    git config --global commit.gpgsign true
    git config --global gpg.ssh.allowedSignersFile "$ALLOWED_SIGNERS"

    USER_EMAIL="$(git config --global user.email || git config --system user.email || true)"
    if [ -n "$USER_EMAIL" ]; then
        echo "${USER_EMAIL} namespaces=\"git\" $(cat "$SSH_KEY_PUB")" > "$ALLOWED_SIGNERS"
        echo "Configured allowed_signers for $USER_EMAIL"
    else
        echo "Git user.email not set yet; writing allowed_signers entry with wildcard..."
        echo "* namespaces=\"git\" $(cat "$SSH_KEY_PUB")" > "$ALLOWED_SIGNERS"
    fi
else
    echo "Note: $SSH_KEY_PUB not found. Skipping SSH commit signing configuration."
fi

echo "==> Dev Container postCreate setup completed."
