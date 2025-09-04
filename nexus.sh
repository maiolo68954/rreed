#!/bin/bash

# Nexus CLI Installer Script
echo "🚀 Installing Nexus CLI..."
curl -s https://cli.nexus.xyz/ | sh

# Reload shell configs
if [ -f "/root/.bashrc" ]; then
    source /root/.bashrc
    echo "✔ Loaded /root/.bashrc"
elif [ -f "/root/.profile" ]; then
    source /root/.profile
    echo "✔ Loaded /root/.profile"
else
    echo "⚠ No .bashrc or .profile found, please add nexus binary to PATH manually."
fi

# Ask user for Node ID
read -p "👉 Enter your node ID: " NODE_ID

# Start node
echo "🚀 Starting Nexus Node with ID: $NODE_ID"
nexus-network start --node-id "$NODE_ID"
