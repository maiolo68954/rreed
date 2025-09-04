#!/bin/bash

# 1️⃣ Nexus CLI Install
echo "🔹 Installing Nexus CLI..."
curl -s https://cli.nexus.xyz/ | sh

# 2️⃣ Add Nexus CLI to PATH for this script
if [ -d "$HOME/.nexus/bin" ]; then
    export PATH="$HOME/.nexus/bin:$PATH"
    echo "🔹 Nexus CLI path added to PATH"
else
    echo "⚠️ Warning: Nexus CLI path not found at $HOME/.nexus/bin"
    echo "Check installation manually."
fi

# 3️⃣ Ask user for Node ID
read -p "👉 Enter your Node ID: " NODE_ID

# 4️⃣ Start Nexus Node
echo "🚀 Starting Nexus Node with ID: $NODE_ID"
nexus-network start --node-id $NODE_ID
