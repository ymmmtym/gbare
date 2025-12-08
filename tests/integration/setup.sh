#!/bin/bash

# Integration test setup script

set -e

echo "Setting up git server for integration tests..."

# Start docker compose
cd "$(dirname "$0")/.."
docker-compose up -d

# Wait for server to be ready
echo "Waiting for git server to start..."
sleep 5

# Setup SSH
mkdir -p ~/.ssh
if [ ! -f ~/.ssh/id_rsa ]; then
  ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
fi

# Add to known hosts
ssh-keyscan -p 2222 localhost >> ~/.ssh/known_hosts 2>/dev/null

# Copy key to container
docker exec gbare-test-git-server mkdir -p /git-server/keys || true
docker cp ~/.ssh/id_rsa.pub gbare-test-git-server:/git-server/keys/

# Configure SSH
cat > ~/.ssh/config << EOF
Host test-git-server
  HostName localhost
  Port 2222
  User git
  IdentityFile ~/.ssh/id_rsa
  StrictHostKeyChecking no
EOF

echo "Git server is ready!"
echo ""
echo "Run integration tests with:"
echo "  export GBARE_USER=git"
echo "  export GBARE_HOST=localhost"
echo "  export GBARE_PORT=2222"
echo "  export GBARE_PATH=/git-server/repos"
echo "  zsh tests/integration/test.zsh"
