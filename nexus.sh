#!/bin/bash

# ============================
# Nexus CLI Auto Installer
# ============================

echo "🚀 Installing Nexus CLI..."
curl -s https://cli.nexus.xyz/ | sh

# Detect shell config and load
if [ -f "/root/.bashrc" ]; then
    SHELL_CONFIG="/root/.bashrc"
elif [ -f "/root/.profile" ]; then
    SHELL_CONFIG="/root/.profile"
else
    SHELL_CONFIG="$HOME/.bashrc"
fi

# Ensure Nexus binary path is added
if ! grep -q ".nexus/bin" "$SHELL_CONFIG"; then
    echo 'export PATH=$PATH:$HOME/.nexus/bin' >> "$SHELL_CONFIG"
    echo "✔ Added Nexus binary path to $SHELL_CONFIG"
fi

# Reload shell config
source "$SHELL_CONFIG"
echo "✔ Loaded $SHELL_CONFIG"

# Check if nexus-network exists
if ! command -v nexus-network &> /dev/null; then
    echo "❌ nexus-network not found in PATH!"
    echo "👉 Please check if ~/.nexus/bin/nexus-network exists."
    exit 1
fi

# Ask user for Node ID
read -p "👉 Enter your node ID: " NODE_ID

# Start node
echo "🚀 Starting Nexus Node with ID: $NODE_ID"
nexus-network start --node-id "$NODE_ID"
