#!/usr/bin/env bash
set -e

SCRIPT_TO_TEST="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/src/restore_snapshot.sh"

if [ ! -f "$SCRIPT_TO_TEST" ]; then
    echo "Error: Script not found at $SCRIPT_TO_TEST"
    exit 1
fi
chmod +x "$SCRIPT_TO_TEST"

TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

cat > test_restore_snapshot_temporary.json << 'EOF'
{
  "comfyui": "test-hash",
  "git_custom_nodes": {},
  "file_custom_nodes": [],
  "pips": {}
}
EOF

cat > comfy << 'EOF'
#!/bin/bash
if [[ "$1" == "--workspace" && "$3" == "restore-snapshot" ]]; then
    if [[ ! -f "$4" ]]; then
        echo "Error: Snapshot file not found"
        exit 1
    fi
    echo "Mock: Restored snapshot from $4"
    exit 0
fi
EOF

chmod +x comfy
export PATH="$TEST_DIR:$PATH"

echo "Testing snapshot restoration..."
echo "Script location: $SCRIPT_TO_TEST"
"$SCRIPT_TO_TEST"

if [ $? -eq 0 ]; then
    echo "✅ Test passed: Snapshot restoration script executed successfully"
    exit 0
else
    echo "❌ Test failed: Snapshot restoration script failed"
    exit 1
fi
