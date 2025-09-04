#!/bin/bash

# Nexus CLI install
curl https://cli.nexus.xyz/ | sh && source /root/.bashrc

# Ask for Node ID
read -p "👉 Enter your Node ID: " NODE_ID

# Start Nexus node with given Node ID
echo "🚀 Starting Nexus Node with ID: $NODE_ID"
nexus-network start --node-id $NODE_ID
